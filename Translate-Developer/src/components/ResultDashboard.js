import React from "react";

import { RESULT_COPY, RESULT_PLACEHOLDERS, RESULT_TABS } from "../data/view-content.js";
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
        { className: "results-tab-row" },
        h(
          "div",
          { className: "results-tabs", role: "tablist", "aria-label": "결과 섹션" },
          RESULT_TABS.map((tab, index) =>
            h(
              "a",
              {
                key: tab.id,
                className: index === 0 ? "results-tab results-tab-active" : "results-tab",
                href: `#result-${tab.id}`
              },
              tab.label
            )
          )
        ),
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
        renderResultPanel("rewritten", RESULT_TABS[0].label, props.state.result?.rewrittenMessage ?? RESULT_PLACEHOLDERS.rewritten, true, !props.state.result),
        h(
          "div",
          { className: "results-secondary-grid" },
          renderResultPanel("impact", RESULT_TABS[2].label, props.state.result?.confirmedImpact ?? RESULT_PLACEHOLDERS.impact, false, !props.state.result),
          renderResultPanel("context", RESULT_TABS[3].label, props.state.result?.needsMoreContext ?? RESULT_PLACEHOLDERS.context, false, !props.state.result)
        )
      ),
      h(
        "aside",
        {
          className: "glossary-panel",
          id: "result-glossary"
        },
        h("h3", { className: "glossary-title" }, RESULT_COPY.glossaryTitle),
        h("p", { className: "glossary-description" }, RESULT_COPY.glossaryDescription),
        renderGlossaryContent(props.state.result),
        h("p", { className: "glossary-footer" }, footerCopy)
      )
    )
  );
}

/**
 * @param {"rewritten" | "impact" | "context"} id
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
 * @param {import("../engine/types.js").TranslationResult | null} result
 */
function renderGlossaryContent(result) {
  if (!result || result.termExplanations.length === 0) {
    return h("p", { className: "glossary-empty" }, RESULT_COPY.glossaryEmpty);
  }

  return h(
    "div",
    { className: "glossary-table-shell" },
    h(
      "table",
      { className: "glossary-table" },
      h(
        "thead",
        null,
        h(
          "tr",
          null,
          h("th", { scope: "col" }, RESULT_COPY.glossaryColumns.term),
          h("th", { scope: "col" }, RESULT_COPY.glossaryColumns.explanation)
        )
      ),
      h(
        "tbody",
        null,
        result.termExplanations.map((item, index) =>
          h(
            "tr",
            { key: `${item.term}-${index}` },
            h("td", null, item.term),
            h("td", null, item.explanation)
          )
        )
      )
    )
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
