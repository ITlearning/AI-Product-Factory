import React from "react";

const { createElement: h } = React;

/**
 * @param {{ feedback: import("../ui/state.js").Feedback }} props
 */
export function FeedbackBanner(props) {
  if (!props.feedback) {
    return null;
  }

  return h(
    "div",
    {
      className: props.feedback.type === "warning" ? "feedback-banner feedback-banner-warning" : "feedback-banner feedback-banner-error",
      role: "status"
    },
    props.feedback.message
  );
}
