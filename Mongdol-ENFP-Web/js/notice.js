// ArrivalNotice · MomentReminder(App/ArrivalNotice.swift) 포팅 — 알림 일정만 계산하는 순수 함수. 기기 로컬 시각 기준.
import { dayKey, parseKey, shiftKey } from './day.js';
import { fnv1a } from './hash.js';

export const TITLE = '몽돌';
export const BODY = {
  arrival: '어제의 조약돌이 도착했어요.',
  morning: '오늘은 어떤 색을 만나게 될까요.',
  evening: '노을 지는 시간이에요. 순간을 남겨 보는 건 어때요?',
};
export const FREQUENCIES = ['often', 'sometimes', 'off'];
export const FREQUENCY_TITLE = { often: '자주', sometimes: '가끔', off: '받지 않기' };
export const DEFAULT_FREQUENCY = 'sometimes';
const HORIZON = 7;

/** dayKey 의 달력 날짜 다음 날 08시. */
export function arrivalDate(key) {
  const { y, m, d } = parseKey(key);
  return new Date(y, m - 1, d + 1, 8, 0, 0).getTime();
}

/** 오늘 dayKey + (4~8시 사이면) 어제 dayKey — 발화 시각이 지난 날은 뺀다. */
export function arrivalTargets(nowMs) {
  const y = new Date(nowMs);
  y.setDate(y.getDate() - 1);
  return [dayKey(y.getTime()), dayKey(nowMs)].filter((k) => nowMs < arrivalDate(k));
}

export function arrivalPlan({ key, hasPebble, closed, gifted, nowMs }) {
  if (!hasPebble || closed || gifted) return null;
  const at = arrivalDate(key);
  return nowMs < at ? { at, kind: 'arrival', key } : null;
}

/** PebbleNaming.dayNumber — 1970-01-01 부터 센 날 수. */
export function dayNumber(key) {
  const { y, m, d } = parseKey(key || '');
  if (!Number.isInteger(y) || !(m >= 1 && m <= 12) || !(d >= 1 && d <= 31)) return null;
  return Math.round(Date.UTC(y, m - 1, d) / 86400e3);
}

/** 「가끔」이면 달력 한 주(월~일)에 이틀, 요일은 주마다 바뀐다. */
export function fires(key, frequency) {
  if (frequency === 'off') return false;
  if (frequency === 'often') return true;
  const n = dayNumber(key);
  if (n == null) return false;
  // 1970-01-01 은 목요일 — 3일 당겨 월요일부터 센다.
  const day = n + 3;
  const week = Math.floor(day / 7);
  const slot = day - week * 7;
  const first = Number(fnv1a(String(week)) % 7n);
  const second = (first + 2 + Number(fnv1a(`${week}b`) % 3n)) % 7;
  return slot === first || slot === second;
}

const SUNSET = [1060, 1090, 1115, 1140, 1165, 1195, 1195, 1170, 1130, 1090, 1050, 1040]; // 서울 1~12월 15일, 분

/** 해 지는 시각(월 중순 값 사이를 이어 붙임)에서 20분 전, 자정부터 분. */
export function eveningMinutes(key) {
  const { m: mm, d } = parseKey(key);
  if (!mm || !d) return 18 * 60;
  const m = mm - 1;
  const [a, b, t] = d >= 15 ? [m, (m + 1) % 12, (d - 15) / 30] : [(m + 11) % 12, m, (d + 15) / 30];
  return Math.trunc(SUNSET[a] + (SUNSET[b] - SUNSET[a]) * t) - 20;
}

/**
 * 앞으로 보낼 알림 전부 — [{at, kind, key}] (at 순).
 * day: { hasSealedMoments(key), closedAt(key), isGifted(key), todayCount }
 */
export function schedule(day, { nowMs, frequency = DEFAULT_FREQUENCY }) {
  const items = [];
  for (const key of arrivalTargets(nowMs)) {
    const p = arrivalPlan({ key, hasPebble: day.hasSealedMoments(key), closed: day.closedAt(key) != null, gifted: day.isGifted(key), nowMs });
    if (p) items.push(p);
  }
  const arrivals = new Set(items.map((i) => i.key));
  if (frequency !== 'off') {
    const today = dayKey(nowMs);
    for (let offset = 0; offset < HORIZON; offset++) {
      const date = new Date(nowMs);
      date.setDate(date.getDate() + offset);
      const key = dayKey(date.getTime());
      if (!fires(key, frequency)) continue;
      if (key === today && day.todayCount > 0) continue;
      for (const [kind, minutes] of [['morning', 9 * 60], ['evening', eveningMinutes(key)]]) {
        // 아침 도착 소식(08시)이 오는 날엔 아침 한 줄을 뺀다.
        if (kind === 'morning' && arrivals.has(shiftKey(key, -1))) continue;
        // iOS 처럼 발화 날짜는 key 가 아니라 date 의 달력 날짜다(0~4시엔 둘이 하루 어긋난다).
        const at = new Date(date.getFullYear(), date.getMonth(), date.getDate(), Math.floor(minutes / 60), minutes % 60).getTime();
        if (at > nowMs) items.push({ at, kind, key });
      }
    }
  }
  return items.sort((a, b) => a.at - b.at);
}
