// 지금 시각 — 확인용 ?now=2026-09-30T04:10 은 localhost 이거나 ?debug 일 때만 먹는다.
// 시각을 옮긴 동안의 기록은 저장 이름공간을 따로 쓴다(db.js) — 내일 시각으로 미리 본 게 진짜 기록에 남지 않게.
let offset = 0;
let debug = false;
try {
  const params = new URLSearchParams(location.search);
  debug = ['localhost', '127.0.0.1', '[::1]'].includes(location.hostname) || params.has('debug');
  const q = debug ? params.get('now') : null;
  if (q) {
    const t = new Date(q).getTime();
    if (!Number.isNaN(t)) offset = t - Date.now();
  }
} catch { /* 그냥 지금 */ }

export const now = () => Date.now() + offset;
export const isShifted = () => offset !== 0;
export const isDebug = () => debug;
