import React from "react";

import { RESULT_COPY, RESULT_PLACEHOLDERS } from "../data/view-content.js";
import { RichTextContent } from "./RichTextContent.js";

const { createElement: h } = React;

/**
 * @param {{
 *   state: import("../ui/state.js").AppState,
 *   audienceLabel: string,
 *   resultsRef?: import("react").RefObject<HTMLElement | null>
 * }} props
 */
export function ResultDashboard(props) {
  if (!props.state.result) {
    return null;
  }

  const footerCopy =
    props.state.engineSource === "ai"
      ? RESULT_COPY.footerBySource.ai
      : props.state.engineSource === "fallback"
        ? RESULT_COPY.footerBySource.fallback
        : RESULT_COPY.footerBySource.idle;

  return h(
    "section",
    {
      className: "results-section",
      id: "results",
      ref: props.resultsRef
    },
    h(
      "div",
      { className: "results-header" },
      h("h2", { className: "results-title" }, RESULT_COPY.title),
      h("p", { className: "results-subtitle" }, `${props.audienceLabel}${RESULT_COPY.descriptionSuffix}`),
      h(
        "div",
        { className: "results-toolbar" },
        h("span", { className: "results-kicker" }, RESULT_COPY.primaryCardTitle),
        h(
          "span",
          {
            className: getEngineBadgeClassName(props.state.engineSource),
            "data-engine-source": props.state.engineSource ?? "idle"
          },
          getEngineBadgeLabel(props.state.engineSource)
        )
      )
    ),
    h(
      "div",
      { className: "results-grid" },
      h(
        "div",
        { className: "results-main-column" },
        renderResultPanel(
          "rewritten",
          RESULT_COPY.primaryCardTitle,
          props.state.result?.rewrittenMessage ?? RESULT_PLACEHOLDERS.rewritten,
          true,
          !props.state.result
        ),
        h("p", { className: "results-footer" }, footerCopy)
      )
    )
  );
}

/**
 * @param {"rewritten"} id
 * @param {string} title
 * @param {string} value
 * @param {boolean} isPrimary
 * @param {boolean} isPlaceholder
 */
function renderResultPanel(id, title, value, isPrimary, isPlaceholder) {
  const className = isPrimary
    ? isPlaceholder
      ? "result-card result-card-primary result-card-placeholder"
      : "result-card result-card-primary"
    : isPlaceholder
      ? "result-card result-card-placeholder"
      : "result-card";

  return h(
    "article",
    {
      className,
      id: `result-${id}`
    },
    h("h3", { className: "result-card-title" }, title),
    h(RichTextContent, {
      value,
      variant: isPrimary ? "primary" : "default"
    })
  );
}

/**
 * @param {"ai" | "fallback" | null} source
 */
function getEngineBadgeLabel(source) {
  if (source === "ai") {
    return "AI 설명";
  }

  if (source === "fallback") {
    return "기본 설명 모드";
  }

  return "입력 대기";
}

/**
 * @param {"ai" | "fallback" | null} source
 */
function getEngineBadgeClassName(source) {
  if (source === "ai") {
    return "engine-badge engine-badge-ai";
  }

  if (source === "fallback") {
    return "engine-badge engine-badge-fallback";
  }

  return "engine-badge";
}
