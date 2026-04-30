import { useEffect, useState } from "react";

import { Landing } from "./pages/Landing.jsx";
import "./pages/Landing.css";

/**
 * SPA 내부 이동 — history.pushState 후 popstate 디스패치해서
 * App의 useState를 갱신한다. v1은 React Router 안 씀.
 */
function navigate(to) {
  if (typeof window === "undefined") return;
  window.history.pushState({}, "", to);
  window.dispatchEvent(new PopStateEvent("popstate"));
}

function ComingSoon({ label }) {
  return (
    <div className="placeholder">
      <div className="placeholder__shell">
        <p className="placeholder__label">{label}</p>
        <h1 className="placeholder__title">준비 중이에요</h1>
        <p className="placeholder__sub">
          잠시 후 다시 들러주세요. 다른 작업자가 만들고 있어요.
        </p>
        <button
          type="button"
          className="placeholder__back"
          onClick={() => navigate("/")}
        >
          처음으로 돌아가기
        </button>
      </div>
    </div>
  );
}

function NotFound() {
  return (
    <div className="placeholder">
      <div className="placeholder__shell">
        <p className="placeholder__label">404</p>
        <h1 className="placeholder__title">없는 페이지예요</h1>
        <p className="placeholder__sub">주소를 다시 확인해주세요.</p>
        <button
          type="button"
          className="placeholder__back"
          onClick={() => navigate("/")}
        >
          처음으로 돌아가기
        </button>
      </div>
    </div>
  );
}

export function App() {
  const [pathname, setPathname] = useState(
    typeof window === "undefined" ? "/" : window.location.pathname,
  );

  useEffect(() => {
    const onPopstate = () => setPathname(window.location.pathname);
    window.addEventListener("popstate", onPopstate);
    return () => window.removeEventListener("popstate", onPopstate);
  }, []);

  if (pathname === "/") {
    return <Landing onStart={() => navigate("/check")} />;
  }
  if (pathname === "/check") {
    return <ComingSoon label="폼 페이지 준비 중" />;
  }
  if (pathname.startsWith("/r/")) {
    return <ComingSoon label="결과 페이지 준비 중" />;
  }
  return <NotFound />;
}
