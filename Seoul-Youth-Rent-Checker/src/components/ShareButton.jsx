import "./ShareButton.css";

// P3 결정: 공유 URL은 항상 도구 root (origin)다.
// 결과 페이지 URL이나 결과 데이터(자격 OK/NO, 보증금, 소득)는 절대 공유에 포함하지 않는다.
const SHARE_TEXT = "5분 안에 청년월세지원 자격 확인하기";
const SHARE_TITLE = "청년월세 체커";

function getShareUrl() {
  if (typeof window === "undefined") return "";
  return window.location.origin;
}

export function ShareButton({ variant = "secondary", label = "친구에게도 공유하기" }) {
  const handleClick = async () => {
    const shareUrl = getShareUrl();

    if (typeof navigator !== "undefined" && typeof navigator.share === "function") {
      try {
        await navigator.share({
          url: shareUrl,
          text: SHARE_TEXT,
          title: SHARE_TITLE,
        });
        return;
      } catch (err) {
        // 사용자가 시트를 닫은 경우는 조용히 무시.
        if (err && err.name === "AbortError") return;
        // 그 외 실패는 클립보드 폴백으로.
        await fallbackCopy(shareUrl);
        return;
      }
    }

    await fallbackCopy(shareUrl);
  };

  const fallbackCopy = async (shareUrl) => {
    // URL 먼저 + 줄바꿈 + 텍스트 — 카톡 미리보기에서 URL이 자동 OG 카드 변환되고
    // 텍스트는 카드 아래 코멘트처럼 읽힘.
    const payload = `${shareUrl}\n${SHARE_TEXT}`;
    try {
      if (
        typeof navigator !== "undefined" &&
        navigator.clipboard &&
        typeof navigator.clipboard.writeText === "function"
      ) {
        await navigator.clipboard.writeText(payload);
        if (typeof window !== "undefined" && typeof window.alert === "function") {
          window.alert("링크를 복사했어요. 친구에게 보내주세요!");
        }
        return;
      }
    } catch {
      // clipboard API 실패 → prompt 폴백
    }
    if (typeof window !== "undefined" && typeof window.prompt === "function") {
      window.prompt("링크를 복사하세요:", shareUrl);
    }
  };

  return (
    <button
      type="button"
      className={`share-btn share-btn--${variant}`}
      onClick={handleClick}
      aria-label={label}
    >
      {label}
    </button>
  );
}
