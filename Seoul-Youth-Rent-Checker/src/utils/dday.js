// 2026 서울 청년월세지원 D-day 카운트다운 로직.
// 신청 시작: 2026-05-06 10:00 KST (UTC+9 → UTC: 2026-05-06T01:00:00Z)
// 신청 마감: 2026-05-19 18:00 KST (UTC+9 → UTC: 2026-05-19T09:00:00Z)
//
// phase는 3가지:
//   - "upcoming": 신청 시작 전. "신청 시작까지 5일 23:12:34"
//   - "open":     신청 진행 중. "신청 마감까지 5일 23:12:34"
//   - "ended":    신청 마감 후. "이번 차수 마감"
//
// 일수는 Math.floor + 시·분·초 단위 분리 — 매초 흐르는 카운트다운.
// (Math.ceil 일수만 표시는 시각적 임팩트 약함.)

const APP_START = new Date("2026-05-06T10:00:00+09:00");
const APP_END = new Date("2026-05-19T18:00:00+09:00");

const MS_PER_SECOND = 1000;
const MS_PER_MINUTE = 60 * MS_PER_SECOND;
const MS_PER_HOUR = 60 * MS_PER_MINUTE;
const MS_PER_DAY = 24 * MS_PER_HOUR;

/**
 * @param {number} ms
 * @returns {{days: number, hours: number, minutes: number, seconds: number}}
 */
function splitDuration(ms) {
  const safe = Math.max(0, ms);
  return {
    days: Math.floor(safe / MS_PER_DAY),
    hours: Math.floor((safe % MS_PER_DAY) / MS_PER_HOUR),
    minutes: Math.floor((safe % MS_PER_HOUR) / MS_PER_MINUTE),
    seconds: Math.floor((safe % MS_PER_MINUTE) / MS_PER_SECOND),
  };
}

/**
 * @typedef {object} Dday
 * @property {"upcoming"|"open"|"ended"} phase
 * @property {number} days
 * @property {number} hours
 * @property {number} minutes
 * @property {number} seconds
 * @property {string} label
 * @property {string} note
 */

/**
 * @param {Date} [now]
 * @returns {Dday}
 */
export function calculateDday(now = new Date()) {
  if (now >= APP_END) {
    return {
      phase: "ended",
      days: 0,
      hours: 0,
      minutes: 0,
      seconds: 0,
      label: "이번 차수 마감",
      note: "다음 차수 알림 받기",
    };
  }

  if (now < APP_START) {
    return {
      phase: "upcoming",
      ...splitDuration(APP_START.getTime() - now.getTime()),
      label: "신청 시작까지",
      note: "5/6 10:00 시작",
    };
  }

  return {
    phase: "open",
    ...splitDuration(APP_END.getTime() - now.getTime()),
    label: "신청 마감까지",
    note: "5/19 18:00 마감",
  };
}

/**
 * 카운트다운 형식 문자열 (예: "5일 23:12:34")
 * @param {Dday} dday
 * @returns {string}
 */
export function formatDdayCountdown(dday) {
  if (dday.phase === "ended") return "이번 차수 마감";
  const { days, hours, minutes, seconds } = dday;
  const hh = String(hours).padStart(2, "0");
  const mm = String(minutes).padStart(2, "0");
  const ss = String(seconds).padStart(2, "0");
  if (days > 0) return `${days}일 ${hh}:${mm}:${ss}`;
  return `${hh}:${mm}:${ss}`;
}
