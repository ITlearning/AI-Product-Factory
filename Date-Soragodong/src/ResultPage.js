import React, { useState, useCallback, useEffect, useRef } from "react";
import { parseCourseFromParams, buildResultUrl, buildOgUrl } from "./utils/url.js";
import { redrawCourse, isSameCourse } from "./utils/course.js";

const { createElement: h } = React;

const RESULT_CARDS = [
  { key: "place",     label: "갈 곳",   icon: "🗺️" },
  { key: "food",      label: "먹을 곳", icon: "🍱" },
  { key: "transport", label: "탈 것",   icon: "🚌" },
  { key: "budget",    label: "금액",    icon: "💰" },
];

function Toast({ message, visible }) {
  return h("div", {
    className: `toast ${visible ? "show" : ""}`,
    role: "status",
    "aria-live": "polite",
  }, message);
}

export function ResultPage() {
  const params = new URLSearchParams(window.location.search);
  const initialCourse = parseCourseFromParams(params);

  const [course, setCourse] = useState(initialCourse);
  const [toast, setToast] = useState({ message: "", visible: false });
  const toastTimerRef = useRef(null);

  const showToast = useCallback((message) => {
    clearTimeout(toastTimerRef.current);
    setToast({ message, visible: true });
    toastTimerRef.current = setTimeout(() => {
      setToast(prev => ({ ...prev, visible: false }));
    }, 2800);
  }, []);

  const handleShare = useCallback(async () => {
    if (!course) return;
    const resultUrl = buildResultUrl(course, window.location.origin);
    if (navigator.share) {
      try {
        await navigator.share({ url: resultUrl, title: "데이트 소라고동 🐚" });
      } catch (err) {
        if (err.name !== "AbortError") {
          await copyToClipboard(resultUrl);
        }
      }
    } else {
      await copyToClipboard(resultUrl);
    }
  }, [course]);

  async function copyToClipboard(text) {
    try {
      await navigator.clipboard.writeText(text);
      showToast("링크 복사됨! 연인에게 보내봐요 💌");
    } catch {
      showToast("링크 복사 실패. 주소창에서 직접 복사해주세요.");
    }
  }

  const handleRedraw = useCallback(() => {
    if (!course) return;
    const next = redrawCourse(course);
    if (isSameCourse(next, course)) {
      showToast("이게 최선이에요! 소라고동님도 어쩔 수 없네요 🐚");
      return;
    }
    setCourse(next);
    // Update URL without reload so back-button works
    const nextUrl = buildResultUrl(next, window.location.origin);
    window.history.replaceState(null, "", nextUrl);
  }, [course, showToast]);

  // Error state
  if (!course) {
    return h("div", { className: "error-screen" },
      h("span", { className: "error-emoji" }, "🐚"),
      h("h1", { className: "error-title" }, "소라고동님이 잠시 자리를 비우셨어요"),
      h("p", { className: "error-subtitle" }, "잘못된 링크이거나 데이터가 없어요."),
      h("button", {
        className: "cta-btn",
        style: { width: "auto", padding: "14px 32px" },
        onClick: () => { window.location.href = "/"; },
      }, "처음으로 돌아가기")
    );
  }

  const courseValues = {
    place: course.place,
    food: course.food,
    transport: course.transport,
    budget: course.budget,
  };

  return h("div", { className: "result-page", role: "main" },
    // Stars
    h("div", { className: "stars", "aria-hidden": "true" }),

    h("div", { className: "deco deco-moon", "aria-hidden": "true" }, "🌙"),
    h("div", { className: "deco deco-blossom-1", "aria-hidden": "true" }, "🌸"),

    // Header
    h("header", { className: "result-header" },
      h("p", { className: "result-label" }, "소라고동님의 선택"),
      h("h1", { className: "result-title" }, "오늘의 데이트 코스 🐚")
    ),

    // Result cards
    h("section", {
      className: "result-cards",
      "aria-label": "소라고동님이 뽑아준 오늘의 데이트 코스",
    },
      RESULT_CARDS.map(({ key, label, icon }) =>
        h("div", { key, className: "result-card" },
          h("span", { className: "result-card-icon", "aria-hidden": "true" }, icon),
          h("div", { className: "result-card-content" },
            h("div", { className: "result-card-category" }, label),
            h("div", { className: "result-card-value" }, courseValues[key])
          )
        )
      )
    ),

    // Actions
    h("div", { className: "result-actions" },
      h("button", {
        className: "btn-share",
        onClick: handleShare,
        "aria-label": "공유하기",
      }, "공유하기 💌"),
      h("button", {
        className: "btn-redraw",
        onClick: handleRedraw,
        "aria-label": "다시 뽑기",
      }, "다시 뽑기 🎲")
    ),

    h(Toast, { message: toast.message, visible: toast.visible })
  );
}
