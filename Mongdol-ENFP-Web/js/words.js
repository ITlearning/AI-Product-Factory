// 사진 한 단어 — 원본은 기기 안 Vision 으로 사진에 찍힌 것을 보고 고른다. 웹엔 그게 없어서
// 시간대·계절에 묶인 말만 쓴다(날씨 말·먹을거리 말은 사진을 못 보면 틀리기 쉬워 뺐다). 맞는 말이 없으면 비워 둔다.
import { fnv1a } from './hash.js';
import { timeBand, season } from './day.js';

const SKIP = new Set(['saecham', 'gyeotduri', 'kkini']);
let words = null;

async function load() {
  if (words) return words;
  try {
    const r = await fetch('./data/words.json');
    if (!r.ok) throw new Error(`words.json ${r.status}`);
    const j = await r.json();
    words = j.words.filter((w) => w.times.length && !w.weathers.length && !SKIP.has(w.id));
  } catch (e) {
    // 실패를 기억해 두면 그 세션 내내 단어가 빈다 — 다음에 다시 불러 본다.
    console.warn('[몽돌] 단어 목록을 못 불러왔어요', e);
    return [];
  }
  return words;
}

export async function wordFor(moment) {
  const list = await load();
  const band = timeBand(moment.capturedAt), sea = season(moment.capturedAt);
  const byTime = list.filter((w) => w.times.includes(band));
  const pool = byTime.filter((w) => !w.seasons.length || w.seasons.includes(sea));
  const found = pool.length ? pool : byTime.filter((w) => !w.seasons.length);
  if (!found.length) return null;
  const pick = found.reduce((a, b) => (fnv1a(`${moment.id}:${a.id}`) <= fnv1a(`${moment.id}:${b.id}`) ? a : b));
  return { word: pick.word, meaning: pick.meaning };
}
