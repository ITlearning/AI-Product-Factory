import React from "react";

import { AUDIENCE_OPTIONS } from "../data/audiences.js";

const { createElement: h } = React;

/**
 * @param {{
 *   selectedAudience: import("../engine/types.js").AudienceId,
 *   onSelectAudience: (audience: import("../engine/types.js").AudienceId) => void
 * }} props
 */
export function AudienceTabs(props) {
  return h(
    "div",
    {
      className: "audience-tabs",
      role: "group",
      "aria-label": "독자 선택"
    },
    AUDIENCE_OPTIONS.map((option) =>
      h(
        "button",
        {
          key: option.id,
          className: option.id === props.selectedAudience ? "audience-tab audience-tab-active" : "audience-tab",
          type: "button",
          "aria-pressed": String(option.id === props.selectedAudience),
          onClick: () => props.onSelectAudience(option.id)
        },
        option.label
      )
    )
  );
}
