// 웹 푸시 — 알림 일정(시각·종류)만 서버에 맞춰 둔다. 사진·색·기록은 보내지 않는다.
// 판정은 notice.js(iOS ArrivalNotice · MomentReminder 와 같은 규칙), 보내기는 서버(api/push-send)가 한다.
import { schedule, DEFAULT_FREQUENCY, FREQUENCIES } from './notice.js';
import { meta } from './db.js';
import { now, isShifted } from './clock.js';
import { fnv1a } from './hash.js';
import { installEnv } from './install.js';

export const VAPID_PUBLIC = 'BMp6IztYjf9chtkRnhwzZsRiltnpL9dNIniuoY5YKEq9HwDdXfrmg7Bw4ZJpaL_6uzYbTjrwuaq96fR6iw5Svlo';
const API = './api/push-schedule';
const DAY = 24 * 3600e3;

export const pushSupported = () =>
  'PushManager' in window && 'serviceWorker' in navigator && 'Notification' in window;

/** 'unsupported' | 'needs-install' | 'denied' | 'default' | 'granted' */
export function pushState() {
  if (pushSupported()) return Notification.permission;
  // iOS 는 홈 화면에 둔 몽돌에서만 웹 푸시가 된다.
  const env = installEnv();
  return env === 'ios' || env === 'ios-inapp' ? 'needs-install' : 'unsupported';
}

export function getFrequency() {
  const f = meta.get('reminderFrequency', DEFAULT_FREQUENCY);
  return FREQUENCIES.includes(f) ? f : DEFAULT_FREQUENCY;
}

export function setFrequency(f) {
  if (!FREQUENCIES.includes(f) || f === getFrequency()) return;
  meta.set('reminderFrequency', f);
  requestSync({ immediate: true });
}

async function registration() {
  const reg = await navigator.serviceWorker.getRegistration();
  if (reg?.active) return reg;
  await navigator.serviceWorker.register('./sw.js').catch(() => null);
  return Promise.race([navigator.serviceWorker.ready, new Promise((r) => setTimeout(() => r(null), 10000))]);
}

function keyBytes(b64) {
  const s = (b64 + '='.repeat((4 - (b64.length % 4)) % 4)).replace(/-/g, '+').replace(/_/g, '/');
  return Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
}

async function subscription({ create }) {
  const reg = await registration();
  if (!reg) return null;
  const sub = await reg.pushManager.getSubscription();
  if (sub || !create) return sub;
  return reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: keyBytes(VAPID_PUBLIC) });
}

export async function isSubscribed() {
  if (pushState() !== 'granted' || meta.get('push.off', false)) return false;
  try { return !!(await subscription({ create: false })); } catch { return false; }
}

/**
 * 버튼 클릭 핸들러 안에서 바로 부른다 — 권한 창은 사용자 몸짓 안에서만 뜬다(await 를 앞에 두지 말 것).
 * 권한을 받으면 구독하고 일정을 맞춘다. 결과는 true/false.
 */
export function enableNotices() {
  if (!pushSupported()) return Promise.resolve(false);
  const asked = Notification.permission === 'default'
    ? Promise.resolve(Notification.requestPermission())
    : Promise.resolve(Notification.permission);
  return asked.then(async (p) => {
    if (p !== 'granted') return false;
    meta.remove('push.off');
    try {
      await subscription({ create: true });
    } catch (e) {
      console.warn('push subscribe', e);
      return false;
    }
    await requestSync({ immediate: true, force: true });
    return true;
  });
}

export async function disableNotices() {
  meta.set('push.off', true);
  try { await (await subscription({ create: false }))?.unsubscribe(); } catch { /* 이미 없음 */ }
  await requestSync({ immediate: true });
}

let store = null;
let timer = 0;
let running = Promise.resolve();

async function send(method, body, keepalive) {
  try {
    const res = await fetch(API, {
      method, keepalive, headers: { 'content-type': 'application/json' }, body: JSON.stringify(body),
    });
    return res.ok;
  } catch {
    return false;
  }
}

function dayView() {
  return {
    hasSealedMoments: (k) => store.hasSealedMoments(k),
    closedAt: (k) => store.closedAt(k),
    isGifted: (k) => store.isGifted(k),
    todayCount: store.today.length,
  };
}

/** 받은 날의 도착 소식이 알림 센터에 남아 있으면 걷는다(iOS ArrivalNotice.clear 의 「전달된 것도」 자리). */
async function clearDelivered(reg) {
  try {
    for (const n of await reg.getNotifications()) {
      const m = /^arrival-(\d{4}-\d{2}-\d{2})$/.exec(n.tag || '');
      if (m && store.isGifted(m[1])) n.close();
    }
  } catch { /* 못 걷어도 그만 */ }
}

async function syncOnce({ force = false, keepalive = false } = {}) {
  if (!store?.loaded || isShifted() || !pushSupported()) return;
  const last = meta.get('push.last', null);
  let sub = null;
  if (Notification.permission === 'granted' && !meta.get('push.off', false)) {
    // 권한을 이미 받은 기기면(iOS 처럼) 구독을 알아서 다시 맞춘다.
    try { sub = await subscription({ create: true }); } catch { sub = null; }
  }
  if (!sub) {
    if (last && (await send('DELETE', { endpoint: last.endpoint }, keepalive))) meta.remove('push.last');
    return;
  }
  const reg = await registration();
  if (reg) clearDelivered(reg);
  const { endpoint, keys } = sub.toJSON();
  const items = schedule(dayView(), { nowMs: now(), frequency: getFrequency() });
  const tz = Intl.DateTimeFormat().resolvedOptions().timeZone || null;
  const sig = fnv1a(JSON.stringify([endpoint, items, tz])).toString(16);
  // 같은 내용이면 하루에 한 번만(서버 구독 TTL 연장용) 다시 보낸다.
  if (!force && last?.sig === sig && Date.now() - last.at < DAY) return;
  if (last && last.endpoint !== endpoint) await send('DELETE', { endpoint: last.endpoint }, keepalive);
  const body = { subscription: { endpoint, keys }, items, ...(tz ? { tz } : {}) };
  if (await send('POST', body, keepalive)) meta.set('push.last', { endpoint, sig, at: Date.now() });
}

/** 바뀐 걸 서버 일정에 맞춘다 — 보통은 2초 모아서, immediate 면 바로. 겹쳐 돌지 않게 줄 세운다. */
export function requestSync({ immediate = false, force = false, keepalive = false } = {}) {
  clearTimeout(timer);
  timer = 0;
  if (!immediate) {
    timer = setTimeout(() => { timer = 0; requestSync({ immediate: true }); }, 2000);
    return running;
  }
  running = running.then(() => syncOnce({ force, keepalive })).catch((e) => console.warn('push sync', e));
  return running;
}

export function startPushSync(s) {
  store = s;
  if (!pushSupported() || isShifted()) return;
  store.addEventListener('change', () => requestSync());
  document.addEventListener('visibilitychange', () => {
    if (!document.hidden) requestSync({ immediate: true });
    // 담고 바로 앱을 내리면 2초 모으기를 못 기다린다 — 남은 건 지금 보낸다.
    else if (timer) requestSync({ immediate: true, keepalive: true });
  });
  requestSync({ immediate: true });
}
