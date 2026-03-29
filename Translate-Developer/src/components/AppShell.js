import React from "react";

import { COMPOSER_COPY } from "../data/view-content.js";
import { AudienceTabs } from "./AudienceTabs.js";
import { BrandHeader } from "./BrandHeader.js";
import { ExampleSidebar } from "./ExampleSidebar.js";
import { FeedbackBanner } from "./FeedbackBanner.js";
import { ResultDashboard } from "./ResultDashboard.js";

const { createElement: h } = React;

/**
 * @param {{
 *   state: import("../ui/state.js").AppState,
 *   selectedAudience: { label: string, description: string },
 *   examples: string[],
 *   onInputChange: (value: string) => void,
 *   onSubmit: (event: SubmitEvent) => void,
 *   onSelectAudience: (audience: import("../engine/types.js").AudienceId) => void,
 *   onSelectExample: (example: string) => void,
 *   resultsRef?: import("react").RefObject<HTMLElement | null>
 * }} props
 */
export function AppShell(props) {
  return h(
    "main",
    { className: "app-shell" },
    h(BrandHeader),
    h(
      "section",
      {
        className: "composer-section",
        "aria-labelledby": "composer-title"
      },
      h(
        "div",
        { className: "composer-column" },
        h("span", { className: "audience-chip" }, props.selectedAudience.label),
        h("h1", { className: "composer-title", id: "composer-title" }, COMPOSER_COPY.title),
        h("p", { className: "composer-description" }, COMPOSER_COPY.description),
        h(AudienceTabs, {
          selectedAudience: props.state.audience,
          onSelectAudience: props.onSelectAudience
        }),
        h(
          "form",
          {
            className: "composer-form",
            "data-role": "composer",
            onSubmit: props.onSubmit
          },
          h(
            "label",
            {
              className: "composer-label",
              htmlFor: "developer-message"
            },
            h("span", { className: "composer-label-text" }, COMPOSER_COPY.textareaLabel)
          ),
          h("textarea", {
            id: "developer-message",
            name: "developer-message",
            value: props.state.input,
            placeholder: COMPOSER_COPY.textareaPlaceholder,
            onChange: (event) => props.onInputChange(event.currentTarget.value)
          }),
          h(FeedbackBanner, {
            feedback: props.state.feedback
          }),
          h(
            "button",
            {
              className: "submit-button",
              type: "submit",
              disabled: props.state.isLoading
            },
            props.state.isLoading ? COMPOSER_COPY.submitLoadingLabel : COMPOSER_COPY.submitIdleLabel
          )
        )
      ),
      h(
        "div",
        { className: "composer-divider", "aria-hidden": "true" },
        h("span", null)
      ),
      h(ExampleSidebar, {
        examples: props.examples,
        onSelectExample: props.onSelectExample
      })
    ),
    h(ResultDashboard, {
      state: props.state,
      audienceLabel: props.selectedAudience.label,
      resultsRef: props.resultsRef
    })
  );
}
