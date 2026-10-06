// PebbleNaming (Shared/Day/PebbleName.swift) — 이름을 고르는 규칙은 원본 그대로, 한 줄만 ENFP 말투로 새로 썼다.
// 원칙은 같다: 그날이 어땠는지, 색이 좋은지 나쁜지 판단하지 않는다(「어두운 색도」·「럭키」 같은 말 금지). 감탄은 돌과 색 그 자체와 「붙잡은 순간」에게만.
import { hexToRgb } from './shape.js';

const value = (c) => Math.max(...c);
const saturation = (c) => { const mx = value(c), mn = Math.min(...c); return mx <= 0 ? 0 : (mx - mn) / mx; };
function hue([r, g, b]) {
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn;
  if (d <= 0) return 0;
  let h;
  if (mx === r) h = 60 * (((g - b) / d) % 6);
  else if (mx === g) h = 60 * ((b - r) / d + 2);
  else h = 60 * ((r - g) / d + 4);
  return h < 0 ? h + 360 : h;
}

export const NAMES = {
  그믐: '한밤 하늘처럼 깊고 고요한 돌이에요!',
  먹빛: '먹을 곱게 갈아 둔 것처럼 매끈해요!',
  잿빛: '차분한 은빛, 볼수록 세련됐어요!',
  안개: '몽글몽글, 구름 한 조각 같아요!',
  해미: '바다 안개처럼 뽀얗고 보드라워요!',
  불씨: '작아도 반짝, 꺼질 생각이 없대요!',
  노을: '저무는 빛까지 예쁘면 반칙이지!',
  아람: '천천히 익는 중! 기대된다 기대돼',
  볕뉘: '잠깐 든 볕 한 줄기를 붙잡았네요!',
  햇귀: '와, 하루가 이런 데서 시작되는구나!',
  이끼: '촉촉한 초록, 만지면 폭신할 것 같아요!',
  풀빛: '초록초록! 보기만 해도 기운 나요',
  물빛: '흘러가는 것도 이렇게 반짝여요!',
  너울: '깊은 바다색, 물결 소리가 들릴 것 같아요!',
  하늘빛: '고개 들어 하늘 본 거, 너무 좋다!',
  미리내: '밤이 깊을수록 별이 더 잘 보여요!',
  새벽빛: '동트기 직전의 푸른빛, 짠!',
  어스름: '낮과 밤 사이에도 색이 있다니!',
  꽃물: '꽃물 들었다! 쉽게 안 지워질걸요?',
};

const named = (name) => ({ name, line: NAMES[name] });

export function representative(moments) {
  const colors = moments.map((m) => hexToRgb(m.colorHex));
  if (!colors.length) return null;
  return colors.reduce((a, b) => (saturation(b) > saturation(a) ? b : a));
}

export function nameFor(moments) {
  const c = representative(moments);
  return c ? nameForColor(c) : null;
}

export function nameForColor(c) {
  const s = saturation(c), v = value(c), h = hue(c);
  if (s < 0.12) {
    if (v < 0.18) return named('그믐');
    if (v < 0.38) return named('먹빛');
    if (v < 0.62) return named('잿빛');
    if (v < 0.85) return named('안개');
    return named('해미');
  }
  const dark = v < 0.42;
  if (h >= 345 || h < 18) return named(dark ? '불씨' : '노을');
  if (h < 45) return named(dark ? '아람' : '볕뉘');
  if (h < 70) return named('햇귀');
  if (h < 160) return named(dark ? '이끼' : '풀빛');
  if (h < 200) return named('물빛');
  if (h < 235) return named(dark ? '너울' : '하늘빛');
  if (h < 265) return named(dark ? '미리내' : '새벽빛');
  if (h < 300) return named('어스름');
  return named('꽃물');
}

/** 받침 있으면 「을」 — Keepsake.objectParticle */
export function objectParticle(word) {
  const v = word.codePointAt(word.length - 1);
  if (v == null || v < 0xac00 || v > 0xd7a3) return '을';
  return (v - 0xac00) % 28 === 0 ? '를' : '을';
}
