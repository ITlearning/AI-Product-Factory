// DayStore · DayClosures · GiftLog (Shared/Day) 를 한 곳에 — 판정 규칙은 원본과 같다.
import * as db from './db.js';
import { dayKey, sealDate, pendingGift, sortByTime } from './day.js';
import { now } from './clock.js';

class Store extends EventTarget {
  constructor() {
    super();
    this.all = new Map();
    this.byDay = new Map();
    this.keys = [];
    this.loaded = false;
    this.closures = db.meta.get('closures', {});
    this.gifted = new Set(db.meta.get('gifted', []));
  }

  async load() {
    const list = await db.loadMoments();
    this.all = new Map(list.map((m) => [m.id, m]));
    this.reindex();
    this.loaded = true;
    this.emit();
  }

  reindex() {
    this.byDay = new Map();
    for (const m of this.all.values()) {
      m.dayKey = dayKey(m.capturedAt);
      if (!this.byDay.has(m.dayKey)) this.byDay.set(m.dayKey, []);
      this.byDay.get(m.dayKey).push(m);
    }
    for (const [k, v] of this.byDay) this.byDay.set(k, sortByTime(v));
    this.keys = [...this.byDay.keys()].sort().reverse();
  }

  emit() { this.dispatchEvent(new Event('change')); }

  get todayKey() { return dayKey(now()); }
  get isEmpty() { return this.all.size === 0; }
  momentsOn(key) { return this.byDay.get(key) || []; }
  get today() { return this.momentsOn(this.todayKey); }
  moment(id) { return this.all.get(id) || null; }

  closedAt(key) { return this.closures[key] ?? null; }

  isFinished(key) {
    const today = this.todayKey;
    if (key < today) return true;
    if (key !== today) return false;
    return this.closedAt(key) != null;
  }

  /** 닫힌 시각 — 마무리하기로 일찍 닫았으면 그 시각, 아니면 다음 날 04:00. */
  sealDateOn(key) {
    const natural = sealDate(key);
    const c = this.closedAt(key);
    return c == null ? natural : Math.min(c, natural);
  }

  canClose(key) {
    return key === this.todayKey && !this.isFinished(key) && this.momentsOn(key).length > 0;
  }

  hasSealedMoments(key) {
    const seal = this.sealDateOn(key);
    return this.momentsOn(key).some((m) => (m.addedAt ?? m.capturedAt) <= seal);
  }

  /** 조약돌에 든 순간 — 닫힌 뒤 담은 사진은 시간축에만 보이고 색은 그대로. */
  pebbleMoments(key) {
    const all = this.momentsOn(key);
    const seal = this.sealDateOn(key);
    const sealed = all.filter((m) => (m.addedAt ?? m.capturedAt) <= seal);
    if (sealed.length) return sealed;
    // 조약돌이 없던 지난 날에 사진첩에서 담으면 처음 담은 묶음으로 조용히 조약돌이 생긴다.
    const withAdded = all.filter((m) => m.addedAt != null);
    if (!withAdded.length) return all;
    const firstBatch = withAdded.reduce((a, b) => (a.addedAt <= b.addedAt ? a : b)).batchID;
    return firstBatch ? all.filter((m) => m.batchID === firstBatch) : all;
  }

  get finishedDayKeys() { return this.keys.filter((k) => this.isFinished(k)); }

  close(key, at = now()) {
    // 이미 닫힌 날을 다시 닫으면 닫힌 시각이 늦춰져 나중 사진이 조약돌에 섞일 수 있다.
    if (this.closures[key] != null) return;
    this.closures = { ...this.closures, [key]: at };
    db.meta.set('closures', this.closures);
    this.emit();
  }

  // GiftLog — 받은 날 중 가장 최근 이하는 전부 받은 것으로 본다(원본 floor 규칙).
  get giftFloor() {
    let max = null;
    for (const k of this.gifted) if (max == null || k > max) max = k;
    return max;
  }
  isGifted(key) { const f = this.giftFloor; return f != null && key <= f; }
  markGifted(key) {
    if (this.isGifted(key)) return;
    this.gifted.add(key);
    db.meta.set('gifted', [...this.gifted]);
    this.emit();
  }

  pendingGift() {
    if (!this.loaded) return null;
    return pendingGift({
      dayKeys: this.keys,
      today: this.todayKey,
      isGifted: (k) => this.isGifted(k),
      hasSealedMoments: (k) => this.hasSealedMoments(k),
      isFinished: (k) => this.isFinished(k),
    });
  }

  /** 같은 파일(이름·크기·수정 시각)을 이미 담았는지 — 원본 DayStore 의 fileName/originalName 중복 가드 자리. */
  hasFileSig(sig) {
    if (!sig) return false;
    for (const m of this.all.values()) if (m.fileSig === sig) return true;
    return false;
  }

  async add(entries) {
    if (!entries.length) return;
    await db.saveMoments(entries);
    for (const { moment } of entries) this.all.set(moment.id, moment);
    this.reindex();
    this.emit();
    db.askPersist();
  }

  async updateMoment(m) {
    this.all.set(m.id, m);
    const { dayKey: _drop, ...plain } = m;
    await db.updateMoment(plain);
  }

  async clear() {
    await db.clearAll();
    this.all.clear();
    this.closures = {};
    this.gifted = new Set();
    db.meta.remove('closures');
    db.meta.remove('gifted');
    this.reindex();
    this.emit();
  }

  /** 견본 채우기처럼 받은 날을 한꺼번에 표시 — 알리지 않는다. */
  setGiftedFloor(key) {
    this.gifted.add(key);
    db.meta.set('gifted', [...this.gifted]);
  }
}

export const store = new Store();
