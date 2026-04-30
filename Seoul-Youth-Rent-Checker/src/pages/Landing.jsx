import { useEffect, useState } from "react";

import { calculateDday, formatDdayCountdown } from "../utils/dday.js";

export function Landing({ onStart }) {
  // 매초 카운트다운 갱신 — 시·분·초 흐르는 느낌.
  const [dday, setDday] = useState(() => calculateDday());
  useEffect(() => {
    const id = window.setInterval(() => setDday(calculateDday()), 1000);
    return () => window.clearInterval(id);
  }, []);
  const isClosed = dday.phase === "ended";

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

  const ctaLabel = isClosed
    ? "다음 차수 알림 받기"
    : dday.phase === "upcoming"
      ? "미리 진단해보기"
      : "시작하기";

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
          <div
            className="landing__dday"
            role="group"
            aria-label={isClosed ? "신청 마감" : dday.label}
          >
            {isClosed ? (
              <>
                <span className="landing__dday-label">{dday.label}</span>
                <span className="landing__dday-countdown">
                  <span className="landing__dday-closed">
                    다음 차수 알림 받기 →
                  </span>
                </span>
              </>
            ) : (
              <>
                <span className="landing__dday-label">{dday.label}</span>
                <span
                  className="landing__dday-countdown"
                  aria-live="polite"
                  aria-atomic="true"
                >
                  {formatDdayCountdown(dday)}
                </span>
                <span className="landing__dday-note">{dday.note}</span>
              </>
            )}
          </div>

          <button
            type="button"
            className="landing__cta"
            onClick={handleClick}
          >
            {ctaLabel}
          </button>

          <p className="landing__footnote">
            월 20만원 × 12개월 / 생애 1회 / 모집 15,000명
          </p>
        </div>
      </div>
    </main>
  );
}
