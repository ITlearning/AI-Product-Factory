// 생일 → 우리말 표(data/birthday.json). 같은 생일이면 누구나 같은 말.
//   node tools/build-birthday.mjs        (시드가 고정이라 같은 원본이면 같은 표)
// 원본 data/birthday-words.json — 앱 단어(Color-Moments/Shared/Word/words.json)와 표준국어대사전 고유어 후보를 합쳐
// 말마다 「생일에 받기 좋은가」와 「어울리는 달」을 뜻풀이를 읽고 정해 둔 것(2026-10-12, 좋은 말 1,277개만 남김).
// months 가 빈 말은 아무 때나 어울린다.
import { readFileSync, writeFileSync } from 'node:fs';

const words = JSON.parse(readFileSync(new URL('../data/birthday-words.json', import.meta.url), 'utf8'));

let seed = 20261012; // mulberry32
const rand = () => { seed |= 0; seed = (seed + 0x6D2B79F5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
const shuffle = (xs) => { for (let i = xs.length - 1; i > 0; i--) { const j = Math.floor(rand() * (i + 1)); [xs[i], xs[j]] = [xs[j], xs[i]]; } return xs; };
const key = (m, d) => String(m).padStart(2, '0') + String(d).padStart(2, '0');

const days = [];
for (let m = 1; m <= 12; m++) for (let d = 1; d <= new Date(2024, m, 0).getDate(); d++) days.push([m, d]);
const inMonth = (m) => words.filter((w) => w.months.includes(m));
const anytime = words.filter((w) => w.months.length === 0);

// 대표 말 — 그 달에 어울리는 말만. 고를 말이 적은 달부터 채워야, 두 달에 걸친 말이 넉넉한 달에서 먼저 빠지지 않는다.
// 한 달에만 어울리는 말(벚꽃 → 4월)을 먼저 쓰고, 날짜에는 섞어서 나눠 준다.
// 날짜가 정해진 말은 제 날에 — 섞어 나누면 어린이날이 5월 29일에 간다.
const PIN = { '0101': '해맞이', '0505': '어린이날', '0508': '어버이날', '1231': '해넘이' };
const used = new Set(), table = {};
for (const [k, w] of Object.entries(PIN)) {
  const e = words.find((x) => x.w === w);
  if (!e) throw new Error(`고정할 말이 원본에 없다: ${w}`);
  used.add(w); table[k] = { w, m: e.m };
}
for (const m of [...Array(12).keys()].map((i) => i + 1).sort((a, b) => inMonth(a).length - inMonth(b).length)) {
  const ds = shuffle(days.filter(([mm]) => mm === m));
  const c = shuffle(inMonth(m).filter((w) => !used.has(w.w))).sort((a, b) => a.months.length - b.months.length);
  for (const [, d] of ds) {
    if (table[key(m, d)]) continue;
    const w = c.shift() ?? shuffle(anytime.filter((x) => !used.has(x.w)))[0];
    used.add(w.w);
    table[key(m, d)] = { w: w.w, m: w.m };
  }
}

// 곁말 두 개 — 그 달에 어울리는 말 하나 + 아무 때나 좋은 말 하나. 다른 날 대표 말은 쓰지 않고, 한 말은 많아야 세 날.
const uses = new Map(), count = (w) => uses.get(w.w) ?? 0;
for (const [m, d] of days) {
  const pick = [];
  for (const pool of [inMonth(m), anytime, inMonth(m), anytime]) {
    if (pick.length === 2) break;
    const c = shuffle(pool.filter((w) => !used.has(w.w) && count(w) < 3 && !pick.includes(w))).sort((a, b) => count(a) - count(b));
    if (c[0]) pick.push(c[0]);
  }
  pick.forEach((w) => uses.set(w.w, count(w) + 1));
  table[key(m, d)].x = pick.map((w) => ({ w: w.w, m: w.m }));
}

const out = Object.fromEntries(Object.keys(table).sort().map((k) => [k, table[k]]));
writeFileSync(new URL('../data/birthday.json', import.meta.url), JSON.stringify(out) + '\n');
console.log(`${Object.keys(out).length}일 · 좋은 말 ${words.length}개(철 있는 말 ${words.length - anytime.length}개)`);
