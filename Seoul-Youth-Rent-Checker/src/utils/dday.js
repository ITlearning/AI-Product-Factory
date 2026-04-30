// 2026 서울 청년월세지원 D-day 카운트다운 로직.
// 신청 시작: 2026-05-06 10:00 KST (UTC+9 → UTC: 2026-05-06T01:00:00Z)
// 신청 마감: 2026-05-19 18:00 KST (UTC+9 → UTC: 2026-05-19T09:00:00Z)
//
// phase는 3가지:
//   - "upcoming": 신청 시작 전. "신청 시작까지 N일 남음".
//   - "open":     신청 진행 중. "신청 마감까지 N일 남음".
//   - "ended":    신청 마감 후. "이번 차수 마감".
//
// 일수는 Math.ceil — "오늘 N일 남음"을 자연스럽게 보이게.
// floor는 마감 당일에 0 떠서 어색.

const APP_START = new Date("2026-05-06T10:00:00+09:00");
const APP_END = new Date("2026-05-19T18:00:00+09:00");
const MS_PER_DAY = 24 * 60 * 60 * 1000;

export function calculateDday(now = new Date()) {
  if (now >= APP_END) {
    return {
      phase: "ended",
      days: 0,
      label: "이번 차수 마감",
      note: "다음 차수 알림 받기",
    };
  }

  if (now < APP_START) {
    const days = Math.ceil((APP_START.getTime() - now.getTime()) / MS_PER_DAY);
    return {
      phase: "upcoming",
      days,
      label: "신청 시작까지",
      note: "5/6 10:00 시작",
    };
  }

  const days = Math.ceil((APP_END.getTime() - now.getTime()) / MS_PER_DAY);
  return {
    phase: "open",
    days,
    label: "신청 마감까지",
    note: "5/19 18:00 마감",
  };
}
