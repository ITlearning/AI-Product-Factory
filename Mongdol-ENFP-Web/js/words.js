// 사진 한 단어 — 앱(Shared/Word/WordPicker.swift)의 규칙 경로를 옮긴다.
// 웹엔 사진을 볼 모델이 없어서, 사진에 뭐가 찍혔든 날짜·시각만으로 참인 말만 쓴다(tools/build_words.py).
// 날씨·기온은 모른다 — 그런 조건이 붙은 말은 목록에서 이미 뺐다. 시각·달·요일은 한국 시간, 해와 달은 서울로 본다.
import { fnv1a } from './hash.js';
import { meta } from './db.js';

let list = null;
let lunar = null;

async function fetchJSON(path) {
  const r = await fetch(path);
  if (!r.ok) throw new Error(`${path} ${r.status}`);
  return r.json();
}

/** 실패는 기억하지 않는다 — 기억하면 그 세션 내내 단어가 빈다. */
export async function loadWords() {
  if (list && lunar) return list;
  try {
    const [w, l] = await Promise.all([fetchJSON('./data/words.json'), fetchJSON('./data/lunar-days.json')]);
    list = w.words;
    lunar = l.days;
  } catch (e) {
    console.warn('[몽돌] 단어 목록을 못 불러왔어요', e);
    return [];
  }
  return list;
}

// ── PhotoContext ─────────────────────────────

const KOREA = new Intl.DateTimeFormat('en-US', {
  timeZone: 'Asia/Seoul', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', hourCycle: 'h23', weekday: 'short',
});
const WEEKDAY = { Sun: 1, Mon: 2, Tue: 3, Wed: 4, Thu: 5, Fri: 6, Sat: 7 };
const SEOUL = { lat: 37.5665, lon: 126.978 };

function timeBandOf(hour) {
  if (hour >= 4 && hour < 7) return 'dawn';
  if (hour >= 7 && hour < 11) return 'morning';
  if (hour >= 11 && hour < 15) return 'noon';
  if (hour >= 15 && hour < 17) return 'afternoon';
  if (hour >= 17 && hour < 20) return 'dusk';
  return 'night';
}

function seasonOf(month) {
  if (month >= 3 && month <= 5) return 'spring';
  if (month >= 6 && month <= 8) return 'summer';
  if (month >= 9 && month <= 11) return 'autumn';
  return 'winter';
}

const julianDay = (ms) => ms / 86_400_000 + 2_440_587.5;
const fmod = (a, b) => a % b; // Swift truncatingRemainder 와 같게(부호는 a 를 따른다)

/** Celestial.sunAltitude — 해 높이(°), 음수면 해가 진 것. */
export function sunAltitude(ms, lat = SEOUL.lat, lon = SEOUL.lon) {
  const rad = Math.PI / 180;
  const n = julianDay(ms) - 2_451_545.0;
  const meanLongitude = fmod(280.460 + 0.9856474 * n, 360);
  const anomaly = fmod(357.528 + 0.9856003 * n, 360) * rad;
  const eclipticLongitude = (meanLongitude + 1.915 * Math.sin(anomaly) + 0.020 * Math.sin(2 * anomaly)) * rad;
  const obliquity = (23.439 - 0.0000004 * n) * rad;
  const rightAscension = Math.atan2(Math.cos(obliquity) * Math.sin(eclipticLongitude), Math.cos(eclipticLongitude));
  const declination = Math.asin(Math.sin(obliquity) * Math.sin(eclipticLongitude));
  const siderealHours = fmod(18.697374558 + 24.06570982441908 * n, 24);
  const hourAngle = (siderealHours * 15 + lon) * rad - rightAscension;
  const la = lat * rad;
  return Math.asin(Math.sin(la) * Math.sin(declination) + Math.cos(la) * Math.cos(declination) * Math.cos(hourAngle)) / rad;
}

const SYNODIC = 29.530588853;
/** Celestial.moonAge — 마지막 삭에서 며칠. */
export function moonAge(ms) {
  const age = fmod(julianDay(ms) - 2_451_550.1, SYNODIC);
  return age < 0 ? age + SYNODIC : age;
}

export function contextFor(ms) {
  const p = Object.fromEntries(KOREA.formatToParts(new Date(ms)).map((x) => [x.type, x.value]));
  const month = Number(p.month), hour = Number(p.hour);
  return {
    hour,
    month,
    weekday: WEEKDAY[p.weekday],
    timeBand: timeBandOf(hour),
    season: seasonOf(month),
    dateKey: `${p.year}-${p.month}-${p.day}`,
    solarKey: `${p.month}-${p.day}`,
    sunAltitude: sunAltitude(ms),
    moonAge: moonAge(ms),
  };
}

// ── WordPicker ───────────────────────────────

/** judge — 웹 목록엔 날씨·기온 조건이 없어서 yes/no 만 남는다. 음력 표를 못 읽었으면 음력 단어는 고르지 않는다. */
export function fits(w, ctx) {
  if (w.times?.length && !w.times.includes(ctx.timeBand)) return false;
  if (w.hours?.length && !w.hours.includes(ctx.hour)) return false;
  if (w.weekdays?.length && !w.weekdays.includes(ctx.weekday)) return false;
  if (w.seasons?.length && !w.seasons.includes(ctx.season)) return false;
  if (w.months?.length && !w.months.includes(ctx.month)) return false;
  if (w.solar?.length && !w.solar.includes(ctx.solarKey)) return false;
  if (w.sunMin != null && ctx.sunAltitude < w.sunMin) return false;
  if (w.sunMax != null && ctx.sunAltitude > w.sunMax) return false;
  if (w.moonAges?.length && !w.moonAges.some(([a, b]) => a <= ctx.moonAge && ctx.moonAge <= b)) return false;
  if (w.lunar?.length) {
    const keys = lunar?.[ctx.dateKey];
    if (!keys || !w.lunar.some((k) => keys.includes(k))) return false;
  }
  return true;
}

/** 앱의 tier 앞에 한 칸 — 음력·양력 날(설날·한가위·어린이날)은 그날만 오는 말이라 맨 앞. */
function tier(w) {
  if (w.lunar?.length || w.solar?.length) return 0;
  if (w.times?.length || w.hours?.length || w.sunMin != null || w.sunMax != null || w.moonAges?.length) return 2;
  return 3;
}

/** 조건 갈래 수 — 더 꼭 맞는 말부터(WordPicker.specificity 중 웹에 남은 갈래). */
function specificity(w) {
  return [w.times?.length || w.hours?.length, w.sunMin != null || w.sunMax != null, w.seasons?.length || w.months?.length,
    w.moonAges?.length, w.weekdays?.length].filter(Boolean).length;
}

/**
 * 그 순간의 말 후보 — 최근 단어는 먼저 피하고, 없으면 피하지 않는다.
 * 앱과 달리 쉬게 한 말(rest)도 밋밋한 말(fallback)처럼 뒤로 민다 — 웹은 날짜 단어가 더해져 고를 여지가 있다.
 */
export function candidates(ctx, words, { recent = new Set(), banned = new Set(), seed, limit = 8 } = {}) {
  const fitting = words.filter((w) => !banned.has(w.id) && fits(w, ctx));
  for (const skipRecent of [true, false]) {
    const found = fitting.filter((w) => !(skipRecent && recent.has(w.id)));
    if (!found.length) continue;
    const key = (w) => [w.rest || w.fallback ? 1 : 0, tier(w), -specificity(w), fnv1a(`${seed}:${w.id}`)];
    return found.map((w) => ({ w, k: key(w) }))
      .sort((a, b) => {
        for (let i = 0; i < 4; i++) if (a.k[i] !== b.k[i]) return a.k[i] < b.k[i] ? -1 : 1;
        return 0;
      })
      .slice(0, limit).map((x) => x.w);
  }
  return [];
}

/** WordChooser 의 규칙 쪽 — 조약돌 이름은 피하고, ↻ 면 다른 갈래부터. */
export function choose(ctx, words, { recent, banned, seed, pebbleName, skipGroup } = {}) {
  const open = words.filter((w) => w.word !== pebbleName);
  const passes = skipGroup ? [open.filter((w) => w.group !== skipGroup), open] : [open];
  for (const pool of passes) {
    const [first] = candidates(ctx, pool, { recent, banned, seed, limit: 1 });
    if (first) return first;
  }
  return null;
}

// ── 「이 단어는 아니에요」(WordRejections) — 이 브라우저 안에만 ──

const REJECTS = 'wordRejects';
const AVOID_AFTER = 2;
const rejects = () => meta.get(REJECTS, []);
export const hasRejected = (momentID) => rejects().some((r) => r.momentID === momentID);
export const rejectedFor = (momentID) => new Set(rejects().filter((r) => r.momentID === momentID).map((r) => r.wordID));
/** 두 번 넘게 버린 단어는 되도록 피한다 — 한 번은 사진 탓일 수 있다. */
export function avoided() {
  const n = new Map();
  for (const r of rejects()) n.set(r.wordID, (n.get(r.wordID) || 0) + 1);
  return new Set([...n].filter(([, c]) => c >= AVOID_AFTER).map(([id]) => id));
}
export function recordReject(entry) {
  if (hasRejected(entry.momentID)) return;
  meta.set(REJECTS, [...rejects(), { ...entry, at: Date.now() }]);
}

export const toPhotoWord = (w) => ({ wordID: w.id, word: w.word, meaning: w.meaning });
