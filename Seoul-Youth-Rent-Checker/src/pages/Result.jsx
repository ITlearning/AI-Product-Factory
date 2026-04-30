import { useEffect, useMemo, useState } from "react";

import { ShareButton } from "../components/ShareButton.jsx";
import { calculateDday } from "../utils/dday.js";

/**
 * D-day 칩 표시 문자열.
 * - "ended":   "신청 마감"
 * - "upcoming": "D-N (시작)" — 신청 시작까지 N일
 * - "open":    "D-N"        — 신청 마감까지 N일
 */
function formatDdayChip(dday) {
  if (dday.phase === "ended") return "신청 마감";
  if (dday.phase === "upcoming") return `D-${dday.days} 시작`;
  return `D-${dday.days}`;
}

/**
 * 서류 ID → 발급처/링크 메타. 서버는 label만 내려주므로 클라이언트에서 매핑.
 * (서버 응답 + JSON 데이터 의존 안 하고, 라벨 일부 매칭으로 안정적으로 처리)
 */
const DOCUMENT_META = [
  {
    match: "임대차계약서",
    issuer: "동주민센터 또는 인터넷등기소",
    url: "https://www.iros.go.kr",
    note: "확정일자 포함 필수",
  },
  {
    match: "이체확인증",
    issuer: "본인 거래은행 모바일/인터넷뱅킹",
    url: null,
    note: "최근 3개월. 월차임 납부확인서로 대체 가능",
  },
  {
    match: "가족관계증명서",
    issuer: "정부24",
    url: "https://www.gov.kr",
    note: "상세, 공고일 이후 발급",
  },
  {
    match: "행정정보 공동이용 사전동의서",
    issuer: "서울주거포털 자료실",
    url: "https://housing.seoul.go.kr",
    note: "신청 시 시스템에서 다운로드",
  },
  {
    match: "한부모가족증명서",
    issuer: "정부24",
    url: "https://www.gov.kr",
    note: "한부모 가구 추가",
  },
  {
    match: "전세사기피해자",
    issuer: "본인 보유 (국토교통부 발급)",
    url: null,
    note: "결정문 사본",
  },
  {
    match: "혼인관계증명서",
    issuer: "정부24",
    url: "https://www.gov.kr",
    note: "신혼부부 추가",
  },
  {
    match: "병적증명서",
    issuer: "정부24 / 병무청",
    url: "https://www.gov.kr",
    note: "군복무 보정 적용 시",
  },
];

function getDocumentMeta(label) {
  for (const meta of DOCUMENT_META) {
    if (label.includes(meta.match)) return meta;
  }
  return { match: "", issuer: "확인 필요", url: null, note: "" };
}

/**
 * primaryReason의 첫 마침표/구두점까지 잘라내서 헤드라인 보조 문구로 다듬기.
 * 너무 길면 60자에서 자른다.
 */
function shortenReason(reason) {
  if (!reason) return "";
  const trimmed = reason.trim();
  if (trimmed.length <= 60) return trimmed;
  return trimmed.slice(0, 58) + "…";
}

// --- 화면들 ----------------------------------------------------------------

function LoadingView() {
  return (
    <main className="result result--loading">
      <div className="result__shell">
        <p className="result__loading-text">결과 불러오는 중...</p>
      </div>
    </main>
  );
}

function ForbiddenView({ onRetry }) {
  return (
    <main className="result result--state">
      <div className="result__shell">
        <div className="result__forbidden">
          <p className="result__state-label">접근 불가</p>
          <h1 className="result__state-title">본인만 볼 수 있어요</h1>
          <p className="result__state-sub">
            이 결과는 진단을 마친 본인 기기에서만 열 수 있어요.
            <br />
            다른 기기에서 보려면 다시 진단해주세요.
          </p>
          <button type="button" className="result__primary-cta" onClick={onRetry}>
            다시 진단하기
          </button>
        </div>
      </div>
    </main>
  );
}

function ExpiredView({ onRetry }) {
  return (
    <main className="result result--state">
      <div className="result__shell">
        <div className="result__expired">
          <p className="result__state-label">결과 만료</p>
          <h1 className="result__state-title">결과가 사라졌어요</h1>
          <p className="result__state-sub">
            결과는 6개월 동안 보관돼요. 시간이 지나 사라졌거나
            <br />
            처음부터 존재하지 않는 결과예요.
          </p>
          <button type="button" className="result__primary-cta" onClick={onRetry}>
            다시 진단하기
          </button>
        </div>
      </div>
    </main>
  );
}

function ErrorView({ error, onRetry }) {
  return (
    <main className="result result--state">
      <div className="result__shell">
        <div className="result__error">
          <p className="result__state-label">오류</p>
          <h1 className="result__state-title">잠시 후 다시 시도해주세요</h1>
          <p className="result__state-sub">
            {error?.message || "알 수 없는 오류가 발생했어요."}
          </p>
          <button type="button" className="result__primary-cta" onClick={onRetry}>
            다시 시도
          </button>
        </div>
      </div>
    </main>
  );
}

// --- 서류 collapsible ------------------------------------------------------

function DocumentItem({ label }) {
  const [open, setOpen] = useState(false);
  const meta = useMemo(() => getDocumentMeta(label), [label]);
  const id = useMemo(
    () => `doc-${label.replace(/[^a-z0-9가-힣]/gi, "-").slice(0, 24)}-${Math.random().toString(36).slice(2, 6)}`,
    [label],
  );

  return (
    <li
      className={
        open
          ? "result__document-item result__document-item--open"
          : "result__document-item"
      }
    >
      <button
        type="button"
        className="result__document-toggle"
        aria-expanded={open}
        aria-controls={id}
        onClick={() => setOpen((prev) => !prev)}
      >
        <span className="result__document-label">{label}</span>
        <span className="result__document-chevron" aria-hidden="true">
          {open ? "−" : "+"}
        </span>
      </button>
      {open && (
        <div className="result__document-body" id={id}>
          <p className="result__document-issuer">발급처: {meta.issuer}</p>
          {meta.note && <p className="result__document-note">{meta.note}</p>}
          {meta.url && (
            <a
              className="result__document-link"
              href={meta.url}
              target="_blank"
              rel="noopener noreferrer"
            >
              {meta.url.replace(/^https?:\/\//, "")} →
            </a>
          )}
        </div>
      )}
    </li>
  );
}

// --- 알림 옵트인 ----------------------------------------------------------

function NotifySignupForm() {
  const [email, setEmail] = useState("");
  const [submitted, setSubmitted] = useState(false);
  const [touched, setTouched] = useState(false);
  const [loading, setLoading] = useState(false);
  const [serverError, setServerError] = useState(null);

  const valid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!valid || loading) {
      setTouched(true);
      return;
    }

    setLoading(true);
    setServerError(null);

    try {
      const res = await fetch("/api/notify-signup", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ email }),
      });
      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data?.message || `알림 신청 실패 (${res.status})`);
      }
    } catch (err) {
      // 네트워크 실패해도 localStorage엔 백업해둠 (사용자 의도 보존)
      try {
        window.localStorage.setItem("notify-email", email);
        window.localStorage.setItem("notify-email-at", String(Date.now()));
      } catch {
        // 시크릿 모드 — 무시
      }
      setServerError(err?.message || "잠시 후 다시 시도해주세요.");
      setLoading(false);
      return;
    }

    // 백엔드 성공 + localStorage 백업도 같이
    try {
      window.localStorage.setItem("notify-email", email);
      window.localStorage.setItem("notify-email-at", String(Date.now()));
    } catch {
      // 시크릿 모드 — 무시
    }

    setSubmitted(true);
    setLoading(false);
  };

  if (submitted) {
    return (
      <div className="result__notify result__notify--done" role="status">
        <p className="result__notify-done-text">
          마감 1일 전, {email}로 알림 보내드릴게요.
        </p>
      </div>
    );
  }

  return (
    <form className="result__notify" onSubmit={handleSubmit} noValidate>
      <label className="result__notify-label" htmlFor="notify-email-input">
        마감 1일 전 알림 받기
      </label>
      <div className="result__notify-row">
        <input
          id="notify-email-input"
          type="email"
          inputMode="email"
          autoComplete="email"
          className="result__notify-input"
          placeholder="이메일 주소"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          onBlur={() => setTouched(true)}
          aria-invalid={touched && !valid}
          disabled={loading}
        />
        <button
          type="submit"
          className="result__notify-submit"
          disabled={!valid || loading}
        >
          {loading ? "신청 중..." : "알림 신청"}
        </button>
      </div>
      {touched && !valid && (
        <p className="result__notify-error">올바른 이메일 형식이 아니에요.</p>
      )}
      {serverError && (
        <p className="result__notify-error">{serverError}</p>
      )}
    </form>
  );
}

// --- 핵심 결과 화면 -------------------------------------------------------

function SuccessView({ result, onRetry, onHome }) {
  const dday = useMemo(() => calculateDday(), []);
  const ddayChip = formatDdayChip(dday);
  const ddayAriaLabel =
    dday.phase === "ended"
      ? "신청 마감"
      : dday.phase === "upcoming"
        ? `신청 시작까지 ${dday.days}일`
        : `신청 마감까지 ${dday.days}일`;
  const tier = result.tier;
  // 1인 가구 4구간 매트릭스 — rank discriminator
  const isRankedTier = tier && typeof tier === "object" && "rank" in tier;
  // 신혼/한부모/전세사기/청년안심주택 — category-pool discriminator
  const isPoolTier =
    tier && typeof tier === "object" && tier.type === "category-pool";
  const ratioPercent = isRankedTier ? Math.round(tier.ratio * 100) : 0;

  return (
    <main className="result result--success">
      <div className="result__shell">
        <header className="result__hero result__hero--success">
          <p className="result__hero-eyebrow">자격 진단 결과</p>
          <h1 className="result__hero-title">
            받을 수 있어요
            <span className="result__hero-mark" aria-hidden="true">
              <svg viewBox="0 0 24 24" width="32" height="32" aria-hidden="true">
                <path
                  d="M5 12.5l4.5 4.5L20 7"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="2.5"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </span>
          </h1>
          <p className="result__hero-sub">
            {result.monthlyBenefitNote || "월 최대 20만원 (월세금액 한도 내)"}
          </p>
        </header>

        {isRankedTier && (
          <section
            className="result__tier-card result__tier-card--ranked"
            aria-label="추첨 구간"
          >
            <div className="result__tier-header">
              <span className="result__tier-label">내 추첨 구간</span>
              <span
                className="result__tier-dday"
                aria-label={ddayAriaLabel}
              >
                {ddayChip}
              </span>
            </div>
            <div className="result__tier-body">
              <span className="result__tier-rank">{tier.rank}구간</span>
              <span className="result__tier-ratio">
                <span className="result__tier-ratio-num">{ratioPercent}%</span>
                <span className="result__tier-ratio-suffix">추첨</span>
              </span>
            </div>
            <p className="result__tier-note">
              청년 1인 가구 4구간 매트릭스 (보증금/월세/소득별 분배). 동일
              구간 신청자 중 {ratioPercent}% 비율로 무작위 선정돼요.
            </p>
          </section>
        )}

        {isPoolTier && (
          <section
            className="result__tier-card result__tier-card--pool"
            aria-label="가구형태별 추첨"
          >
            <div className="result__tier-header">
              <span className="result__tier-label">내 신청 유형</span>
              <span
                className="result__tier-dday"
                aria-label={ddayAriaLabel}
              >
                {ddayChip}
              </span>
            </div>
            <div className="result__tier-body result__tier-body--pool">
              <span className="result__tier-pool-label">
                {tier.householdLabel}
              </span>
            </div>
            <p className="result__tier-note">
              {tier.label} — 가구형태별 추첨이라 구간 매칭 없이 진행돼요.
            </p>
          </section>
        )}

        <section className="result__section" aria-label="필요 서류">
          <h2 className="result__section-title">필요 서류</h2>
          <ul className="result__document-list">
            {result.requiredDocuments.map((doc) => (
              <DocumentItem key={doc} label={doc} />
            ))}
          </ul>
        </section>

        <section className="result__cta">
          <NotifySignupForm />
          <div className="result__share">
            <ShareButton variant="secondary" />
          </div>
          <button
            type="button"
            className="result__secondary-link"
            onClick={onRetry}
          >
            다시 진단하기
          </button>
          <button
            type="button"
            className="result__secondary-link"
            onClick={onHome}
          >
            처음으로
          </button>
        </section>
      </div>
    </main>
  );
}

function FailView({ result, onRetry, onHome }) {
  const reason = result.primaryReason || "";
  const altSuggestions = result.alternativeProgramSuggestions || [];

  return (
    <main className="result result--fail">
      <div className="result__shell">
        <header className="result__hero result__hero--fail">
          <p className="result__hero-eyebrow">자격 진단 결과</p>
          <h1 className="result__hero-title">이번엔 어려워요</h1>
          <p className="result__hero-sub">{shortenReason(reason)}</p>
        </header>

        {altSuggestions.length > 0 && (
          <section className="result__section" aria-label="대안 프로그램">
            <h2 className="result__section-title">대안 프로그램</h2>
            <ul className="result__alt-list">
              {altSuggestions.map((suggestion) => (
                <li className="result__alt-card" key={suggestion}>
                  <p className="result__alt-text">{suggestion}</p>
                </li>
              ))}
            </ul>
            <p className="result__alt-note">
              위 프로그램들은 별도 기관에서 운영해요. 자세한 자격은 각 기관에서 확인해주세요.
            </p>
          </section>
        )}

        {result.allReasons && result.allReasons.length > 1 && (
          <section className="result__section" aria-label="자세한 사유">
            <h2 className="result__section-title">자세한 사유</h2>
            <ul className="result__reason-list">
              {result.allReasons.map((r) => (
                <li className="result__reason-item" key={r}>
                  {r}
                </li>
              ))}
            </ul>
          </section>
        )}

        <section className="result__cta">
          <div className="result__share">
            <ShareButton variant="secondary" />
          </div>
          <button
            type="button"
            className="result__secondary-link"
            onClick={onRetry}
          >
            다시 진단하기
          </button>
          <button
            type="button"
            className="result__secondary-link"
            onClick={onHome}
          >
            처음으로
          </button>
        </section>
      </div>
    </main>
  );
}

function ResultView({ result, onRetry, onHome }) {
  if (result.eligible) {
    return <SuccessView result={result} onRetry={onRetry} onHome={onHome} />;
  }
  return <FailView result={result} onRetry={onRetry} onHome={onHome} />;
}

// --- 데이터 로더 ---------------------------------------------------------

export function Result({ uuid, onRetry, onHome }) {
  const [state, setState] = useState({ status: "loading" });

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        const res = await fetch(`/api/result/${encodeURIComponent(uuid)}`, {
          credentials: "include",
        });
        const data = await res.json().catch(() => null);
        if (cancelled) return;
        if (res.ok && data) {
          setState({ status: "ok", data });
        } else if (res.status === 403) {
          setState({ status: "forbidden", error: data });
        } else if (res.status === 404) {
          setState({ status: "expired", error: data });
        } else {
          setState({
            status: "error",
            error: data || { message: "알 수 없는 오류가 발생했어요." },
          });
        }
      } catch (err) {
        if (cancelled) return;
        setState({ status: "error", error: { message: err?.message || "네트워크 오류" } });
      }
    }

    load();
    return () => {
      cancelled = true;
    };
  }, [uuid]);

  if (state.status === "loading") return <LoadingView />;
  if (state.status === "forbidden") return <ForbiddenView onRetry={onRetry} />;
  if (state.status === "expired") return <ExpiredView onRetry={onRetry} />;
  if (state.status === "error") return <ErrorView error={state.error} onRetry={onRetry} />;

  return (
    <ResultView
      result={state.data.result}
      onRetry={onRetry}
      onHome={onHome}
    />
  );
}
