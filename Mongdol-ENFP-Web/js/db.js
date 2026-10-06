// 전부 기기 안 — 순간 기록과 사진은 IndexedDB, 작은 표시값(닫은 날·받은 날·온보딩)은 localStorage.
// 어디로도 보내지 않는다.
import { isShifted } from './clock.js';

// ?now= 로 시각을 옮겨 둔 미리 보기는 따로 담는다 — 진짜 기록·받은 날에 섞이지 않게.
const SPACE = isShifted() ? 'preview.' : '';
const DB_NAME = isShifted() ? 'mongdol-enfp-preview' : 'mongdol-enfp';
const DB_VERSION = 1;

let dbPromise = null;
let memory = null; // IndexedDB 를 못 쓰는 환경(일부 file://)에서의 임시 보관

function open() {
  if (dbPromise) return dbPromise;
  const mine = new Promise((resolve) => {
    let req;
    try { req = indexedDB.open(DB_NAME, DB_VERSION); } catch { resolve(null); return; }
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains('moments')) db.createObjectStore('moments', { keyPath: 'id' });
      if (!db.objectStoreNames.contains('photos')) db.createObjectStore('photos', { keyPath: 'id' });
    };
    req.onsuccess = () => {
      const db = req.result;
      // iOS 는 오래 백그라운드에 두면 연결을 끊는다(「Connection to Indexed Database server lost」).
      // 끊긴 연결을 계속 붙들면 저장이 전부 실패하니, 끊기면 다음 요청 때 새로 연다.
      const drop = () => { if (dbPromise === mine) dbPromise = null; };
      db.onclose = drop;
      db.onversionchange = () => { db.close(); drop(); };
      resolve(db);
    };
    req.onerror = () => resolve(null);
    req.onblocked = () => resolve(null);
  }).then((db) => {
    if (!db && !memory) memory = { moments: new Map(), photos: new Map() };
    return db;
  });
  dbPromise = mine;
  return mine;
}

export async function persistent() {
  return !!(await open());
}

function txOnce(db, stores, mode, fn) {
  return new Promise((resolve, reject) => {
    const t = db.transaction(stores, mode);
    let out;
    t.oncomplete = () => resolve(out);
    t.onerror = () => reject(t.error);
    t.onabort = () => reject(t.error);
    // fn 안에서 put 이 바로 던지면 앞서 넣은 것만 커밋되는 반쪽 저장이 된다 — 통째로 되돌린다.
    try { out = fn(t); } catch (e) { try { t.abort(); } catch { /* 이미 끝남 */ } reject(e); }
  });
}

async function tx(db, stores, mode, fn) {
  try {
    return await txOnce(db, stores, mode, fn);
  } catch (e) {
    if (e?.name !== 'InvalidStateError') throw e;
    // 연결이 끊긴 채 남아 있던 경우 — 한 번만 새로 열어 다시 한다.
    if (dbPromise) dbPromise = null;
    const fresh = await open();
    if (!fresh) throw e;
    return txOnce(fresh, stores, mode, fn);
  }
}

const reqValue = (req) => new Promise((resolve, reject) => {
  req.onsuccess = () => resolve(req.result);
  req.onerror = () => reject(req.error);
});

export async function loadMoments() {
  const db = await open();
  if (!db) return [...memory.moments.values()];
  return tx(db, ['moments'], 'readonly', (t) => reqValue(t.objectStore('moments').getAll())).then((p) => p);
}

/** 순간 기록 + 사진(원본 축소본·썸네일)을 한 번에. */
export async function saveMoments(entries) {
  const db = await open();
  if (!db) {
    for (const { moment, full, thumb } of entries) {
      memory.moments.set(moment.id, moment);
      memory.photos.set(moment.id, { id: moment.id, full, thumb });
    }
    return;
  }
  await tx(db, ['moments', 'photos'], 'readwrite', (t) => {
    for (const { moment, full, thumb } of entries) {
      t.objectStore('moments').put(moment);
      if (full || thumb) t.objectStore('photos').put({ id: moment.id, full, thumb });
    }
  });
}

export async function updateMoment(moment) {
  const db = await open();
  if (!db) { memory.moments.set(moment.id, moment); return; }
  await tx(db, ['moments'], 'readwrite', (t) => { t.objectStore('moments').put(moment); });
}

export async function loadPhoto(id) {
  const db = await open();
  if (!db) return memory.photos.get(id) || null;
  const p = await tx(db, ['photos'], 'readonly', (t) => reqValue(t.objectStore('photos').get(id)));
  return (await p) || null;
}

export async function clearAll() {
  const db = await open();
  if (!db) { memory.moments.clear(); memory.photos.clear(); return; }
  await tx(db, ['moments', 'photos'], 'readwrite', (t) => {
    t.objectStore('moments').clear();
    t.objectStore('photos').clear();
  });
}

// ── localStorage (막혀 있어도 앱은 돈다 — 그땐 이번 세션에만 기억한다) ──
const fallback = new Map();
export const meta = {
  get(key, def) {
    try {
      const v = localStorage.getItem(`mongdol.${SPACE}${key}`);
      return v == null ? def : JSON.parse(v);
    } catch {
      return fallback.has(key) ? fallback.get(key) : def;
    }
  },
  set(key, value) {
    fallback.set(key, value);
    try { localStorage.setItem(`mongdol.${SPACE}${key}`, JSON.stringify(value)); } catch { /* 이번 세션만 */ }
  },
  remove(key) {
    fallback.delete(key);
    try { localStorage.removeItem(`mongdol.${SPACE}${key}`); } catch { /* 무시 */ }
  },
};

/** Safari 는 오래 안 연 사이트 저장소를 지울 수 있다 — 첫 기록을 남길 때 한 번 「지워지지 않게」를 청한다. */
let persistAsked = false;
export async function askPersist() {
  if (persistAsked) return null;
  persistAsked = true;
  try {
    if (!navigator.storage?.persist) return null;
    if (await navigator.storage.persisted?.()) return true;
    return await navigator.storage.persist();
  } catch { return null; }
}
