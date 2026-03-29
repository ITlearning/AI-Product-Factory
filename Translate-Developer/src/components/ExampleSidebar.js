import React from "react";

import { EXAMPLE_PANEL_COPY, GUIDANCE_COPY } from "../data/view-content.js";

const { createElement: h } = React;

/**
 * @param {{
 *   examples: string[],
 *   onSelectExample: (example: string) => void
 * }} props
 */
export function ExampleSidebar(props) {
  return h(
    "aside",
    {
      className: "support-sidebar",
      "aria-label": "빠른 예시와 입력 가이드"
    },
    h(
      "section",
      { className: "support-panel" },
      h("h2", { className: "support-heading" }, EXAMPLE_PANEL_COPY.title),
      h(
        "div",
        { className: "example-stack" },
        props.examples.map((example, index) =>
          h(
            "button",
            {
              key: `${index}-${example.slice(0, 12)}`,
              className: "example-card",
              type: "button",
              onClick: () => props.onSelectExample(example)
            },
            h("span", { className: "example-card-copy" }, example)
          )
        )
      )
    ),
    h(
      "section",
      { className: "support-panel support-panel-guide" },
      h("h2", { className: "support-heading" }, GUIDANCE_COPY.title),
      h(
        "ul",
        { className: "guidance-list" },
        GUIDANCE_COPY.items.map((item) =>
          h("li", { key: item }, item)
        )
      )
    )
  );
}
