// Moment.dayKey · DayGradient · DayTimeline · Memories · GiftSchedule 포팅 — 순수 함수만.
import { fnv1a, splitmix, bits16 } from './hash.js';

export const BOUNDARY_HOUR = 4;
const HOUR = 3600e3;
const DAY = 24 * HOUR;

const pad = (n) => String(n).padStart(2, '0');

export function keyOfDate(d) {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

/** 새벽 4시 경계 — 04:00 이전 사진은 전날 하루에 들어간다. */
export function dayKey(ms) {
  const d = new Date(ms);
  d.setHours(d.getHours() - BOUNDARY_HOUR);
  return keyOfDate(d);
}

export function parseKey(key) {
  const [y, m, d] = key.split('-').map(Number);
  return { y, m, d };
}

/** 그 하루가 저절로 닫히는 시각 — 다음 날 04:00. */
export function sealDate(key) {
  const { y, m, d } = parseKey(key);
  return new Date(y, m - 1, d + 1, BOUNDARY_HOUR).getTime();
}

/** 그 하루가 시작되는 시각 — 그날 04:00. */
export function dayStart(key) {
  const { y, m, d } = parseKey(key);
  return new Date(y, m - 1, d, BOUNDARY_HOUR).getTime();
}

export function shiftKey(key, days) {
  const { y, m, d } = parseKey(key);
  return keyOfDate(new Date(y, m - 1, d + days, 12));
}

export const sortByTime = (ms) => [...ms].sort((a, b) => a.capturedAt - b.capturedAt);

/** DayGradient.positions — 첫 촬영~마지막 촬영을 0…1로 펴되 그 안의 비율은 그대로. */
export function positions(moments) {
  const sorted = sortByTime(moments);
  if (!sorted.length) return [];
  if (sorted.length === 1) return [{ moment: sorted[0], loc: 0 }];
  const first = sorted[0].capturedAt, span = sorted[sorted.length - 1].capturedAt - first;
  if (span <= 0) return sorted.map((m, i) => ({ moment: m, loc: i / (sorted.length - 1) }));
  return sorted.map((m) => ({ moment: m, loc: (m.capturedAt - first) / span }));
}

export function stops(moments) {
  return positions(moments).map((p) => ({ loc: p.loc, hex: p.moment.colorHex }));
}

export function span(moments) {
  const s = sortByTime(moments);
  return s.length ? { from: s[0].capturedAt, to: s[s.length - 1].capturedAt } : null;
}

export function cssGradient(moments, dir = '180deg') {
  const st = stops(moments);
  if (!st.length) return 'transparent';
  if (st.length === 1) return st[0].hex;
  return `linear-gradient(${dir}, ${st.map((s) => `${s.hex} ${(s.loc * 100).toFixed(1)}%`).join(', ')})`;
}

/** 흐림 필터 없이 번지는 빛 — 정지점마다 부드러운 타원을 위→아래로 겹친다(움직이는 배경에 blur 를 걸지 않으려고). */
export function softGlow(moments, alpha = 'cc') {
  const st = stops(moments);
  if (!st.length) return 'transparent';
  const pick = st.length <= 4 ? st : [0, 1, 2, 3].map((i) => st[Math.round((i / 3) * (st.length - 1))]);
  return pick.map((s, i) => {
    // 타원이 요소 가장자리에 닿으면 그 선이 보인다 — 안쪽(4%~96%)에서 다 꺼지게 잡는다.
    const x = 50 + (i % 2 ? 12 : -12) * (pick.length > 1 ? 1 : 0);
    const y = 30 + s.loc * 40;
    return `radial-gradient(34% 26% at ${x}% ${y}%, ${s.hex}${alpha}, ${s.hex}00 100%)`;
  }).join(', ');
}

export function timeText(ms) {
  const d = new Date(ms);
  return `${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export function dateText(ms) {
  const d = new Date(ms);
  return `${d.getMonth() + 1}월 ${d.getDate()}일`;
}

export function keyDateText(key) {
  const { m, d } = parseKey(key);
  return `${m}월 ${d}일`;
}

export function monthLabel(month) {
  const [y, m] = month.split('-');
  return `${y}년 ${Number(m)}월`;
}

/** DayTimeline.axisHeight / place */
export function axisHeight(count, photoHeight, maxHeight = 360) {
  if (count <= 1) return 0;
  return Math.min(maxHeight, photoHeight * 1.5 * (count - 1));
}

export function placeTimeline(moments, height, photoHeight, maxShift = 3, minLabelGap = 14) {
  const out = [];
  let lastLabelY = -Infinity;
  for (const p of positions(moments)) {
    const y = p.loc * height;
    let shift = 0;
    const prev = out[out.length - 1];
    if (prev && y < prev.y + photoHeight) shift = (prev.shift + 1) % (maxShift + 1);
    const showsTime = y - lastLabelY >= minLabelGap;
    if (showsTime) lastLabelY = y;
    out.push({ moment: p.moment, y, shift, showsTime });
  }
  return out;
}

/** 30일 지난 하루는 한 줄로 */
export function compactCutoff(nowMs) {
  const d = new Date(nowMs);
  d.setDate(d.getDate() - 30);
  return dayKey(d.getTime());
}

export function monthsOf(keys) {
  return [...new Set(keys.filter((k) => k.length >= 7).map((k) => k.slice(0, 7)))].sort().reverse();
}

/** Memories.months — 이번 달 제외, 받은 하루가 있는 달 최신순 */
export function handfulMonths(giftedDays, today) {
  const cur = today.slice(0, 7);
  return [...new Set([...giftedDays].sort().reverse().map((k) => k.slice(0, 7)))].filter((m) => m !== cur);
}

export function handfulTitle(month, today) {
  const [y, m] = month.split('-');
  return today.startsWith(`${y}-`) ? `${Number(m)}월의 한 줌` : `${y}년 ${Number(m)}월의 한 줌`;
}

/** Memories.lastYear — 1년 전 ±3일 안에서 받은 하루 중 가장 가까운 것 */
export function lastYear(today, giftedDays) {
  const t = parseKey(today);
  const anchorDay = t.m === 2 && t.d === 29 ? 28 : t.d;
  const anchor = Date.UTC(t.y - 1, t.m - 1, anchorDay);
  let best = null;
  for (const k of giftedDays) {
    const p = parseKey(k);
    const diff = Math.abs(Math.round((Date.UTC(p.y, p.m - 1, p.d) - anchor) / DAY));
    if (diff > 3) continue;
    if (!best || diff < best.diff || (diff === best.diff && k < best.key)) best = { key: k, diff };
  }
  return best?.key ?? null;
}

/** Memories.handfulLayout — 한 손(반지름 1의 원) 안에 겹쳐 쌓는 배치 */
export function handfulLayout(count, seed) {
  if (count <= 0) return [];
  const golden = 2.399963229728653;
  const baseScale = count <= 6 ? 1 : Math.max(0.45, 1 - (count - 6) * 0.02);
  return Array.from({ length: count }, (_, i) => {
    const h = splitmix(seed, i);
    const t = i + 0.5;
    const radius = Math.sqrt(t / count);
    const angle = t * golden;
    const jm = 0.08 * (1 - radius);
    const jx = (bits16(h, 0) - 0.5) * 2 * jm;
    const jy = (bits16(h, 16) - 0.5) * 2 * jm;
    let x = radius * Math.cos(angle) + jx, y = radius * Math.sin(angle) + jy;
    const r = Math.hypot(x, y);
    if (r > 1) { x /= r; y /= r; }
    return {
      x, y,
      rotation: (bits16(h, 32) - 0.5) * 60,
      scale: baseScale * (0.85 + bits16(h, 48) * 0.3),
    };
  });
}

export const monthSeed = (month) => fnv1a(month);

/** GiftSchedule.pending — 자연히 끝난 날은 가장 최근 하나만, 그 다음 마무리한 오늘. */
export function pendingGift({ dayKeys, today, isGifted, hasSealedMoments, isFinished }) {
  const natural = dayKeys.find((k) => k < today && hasSealedMoments(k));
  if (natural && !isGifted(natural)) return natural;
  if (dayKeys.includes(today) && isFinished(today) && hasSealedMoments(today) && !isGifted(today)) return today;
  return null;
}

/** BadgeCeremony.openingLine — ENFP 판 */
export function openingLine(key, nowMs) {
  const today = dayKey(nowMs);
  if (key === today) return '짜잔! 오늘이 조약돌이 됐어요';
  if (key === dayKey(nowMs - DAY)) return '짜잔! 어제가 조약돌이 됐어요';
  return '짜잔! 그날이 조약돌이 됐어요';
}

export function timeBand(ms) {
  const h = new Date(ms).getHours();
  if (h >= 4 && h < 7) return 'dawn';
  if (h >= 7 && h < 11) return 'morning';
  if (h >= 11 && h < 15) return 'noon';
  if (h >= 15 && h < 17) return 'afternoon';
  if (h >= 17 && h < 20) return 'dusk';
  return 'night';
}

export function season(ms) {
  const m = new Date(ms).getMonth() + 1;
  if (m >= 3 && m <= 5) return 'spring';
  if (m >= 6 && m <= 8) return 'summer';
  if (m >= 9 && m <= 11) return 'autumn';
  return 'winter';
}
