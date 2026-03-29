import React from "react";

import { BRAND_COPY } from "../data/view-content.js";

const { createElement: h } = React;

export function BrandHeader() {
  return h(
    "header",
    { className: "brand-header" },
    h(
      "div",
      { className: "brand-mark", "aria-hidden": "true" },
      h("span", { className: "brand-mark-korean" }, "文"),
      h("span", { className: "brand-mark-latin" }, "A")
    ),
    h(
      "div",
      { className: "brand-copy" },
      h("strong", null, BRAND_COPY.title),
      h("span", null, BRAND_COPY.subtitle)
    )
  );
}
