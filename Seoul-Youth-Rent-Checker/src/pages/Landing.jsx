import { useEffect, useMemo, useState } from "react";

// 2026 서울 청년월세지원 신청 마감: 2026-05-19 18:00 KST.
// KST = UTC+9 → 마감 순간 UTC: 2026-05-19T09:00:00Z
const DEADLINE_UTC_ISO = "2026-05-19T09:00:00Z";
const MS_PER_DAY = 24 * 60 * 60 * 1000;

/**
 * 마감일까지 남은 일수. 마감 순간을 지나면 0 이하.
 * 일수는 ceil — '오늘 18시 마감'을 '0일 남음'이 아닌 '1일 남음' 표시 방지.
 * 이번엔 floor로 통일: 24h 단위로 자른 정수 → 사용자에게 직관적.
 */
function daysUntil(deadlineIso, now = new Date()) {
  const deadline = new Date(deadlineIso).getTime();
  const diffMs = deadline - now.getTime();
  if (diffMs <= 0) return 0;
  return Math.floor(diffMs / MS_PER_DAY);
}

export function Landing({ onStart }) {
  // 첫 렌더 시점에 한 번 계산. v1은 자정 자동 갱신 X — 페이지 새로고침 기준.
  const remainingDays = useMemo(() => daysUntil(DEADLINE_UTC_ISO), []);
  const isClosed = remainingDays <= 0;

  // 페이지 로드 시 staggered fade-in 트리거.
  // CSS animation-delay를 이미 잡아놨으니 mounted 클래스만 토글.
  const [mounted, setMounted] = useState(false);
  useEffect(() => {
    const id = window.requestAnimationFrame(() => setMounted(true));
    return () => window.cancelAnimationFrame(id);
  }, []);

  const handleClick = () => {
    if (isClosed) {
      // 다음 차수 알림 옵트인은 v2 — 일단 동일 라우팅.
      onStart?.();
      return;
    }
    onStart?.();
  };

  return (
    <main
      className={
        mounted ? "landing landing--mounted" : "landing"
      }
    >
      <div className="landing__shell">
        <div className="landing__top">
          <span className="landing__badge" role="status">
            <span className="landing__badge-dot" aria-hidden="true" />
            2026 서울시 공고 기반
          </span>

          <h1 className="landing__headline">
            청년월세{" "}
            <span className="landing__headline-em">240만원</span>,
            <br />
            너 받을 수 있어?
          </h1>

          <p className="landing__sub">
            5분 자가진단. 공인인증서 필요 없어요.
            <br />
            익명 처리, 결과는 본인만 확인 가능.
          </p>
        </div>

        <div className="landing__bottom">
          <div className="landing__dday" role="group" aria-label="신청 마감 카운트다운">
            <span className="landing__dday-label">신청 마감까지</span>
            <span className="landing__dday-countdown">
              {isClosed ? (
                <span className="landing__dday-closed">신청 마감</span>
              ) : (
                <>
                  <span className="landing__dday-num">{remainingDays}</span>
                  일 남음
                </>
              )}
            </span>
          </div>

          <button
            type="button"
            className="landing__cta"
            onClick={handleClick}
          >
            {isClosed ? "다음 차수 알림 받기" : "시작하기"}
          </button>

          <p className="landing__footnote">
            월 20만원 × 12개월 / 생애 1회 / 모집 15,000명
          </p>
        </div>
      </div>
    </main>
  );
}
