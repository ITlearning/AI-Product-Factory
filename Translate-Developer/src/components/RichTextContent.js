import React from "react";

import { parseRichTextBlocks, renderInlineRichText } from "../utils/rich-text.js";

const { createElement: h } = React;

/**
 * @param {{
 *   value: string,
 *   variant?: "default" | "primary"
 * }} props
 */
export function RichTextContent(props) {
  const variant = props.variant ?? "default";
  const blocks = parseRichTextBlocks(props.value);
  const className = variant === "primary" ? "result-content result-content-primary" : "result-content";

  return h(
    "div",
    { className },
    blocks.map((block, index) => renderBlock(block, index))
  );
}

/**
 * @param {{ type: "paragraph", lines: string[] } | { type: "ul" | "ol", items: string[] }} block
 * @param {number} index
 */
function renderBlock(block, index) {
  if (block.type === "paragraph") {
    const paragraphHtml = block.lines.map(renderInlineRichText).join("<br>");
    const isLabel = block.lines.length === 1 && /[:：]$/.test(block.lines[0]);
    const className = isLabel ? "result-paragraph result-paragraph-label" : "result-paragraph";

    return h("p", {
      key: `paragraph-${index}`,
      className,
      dangerouslySetInnerHTML: {
        __html: isLabel ? `<strong>${paragraphHtml}</strong>` : paragraphHtml
      }
    });
  }

  const tagName = block.type === "ol" ? "ol" : "ul";
  const listClass = block.type === "ol" ? "result-list result-list-ordered" : "result-list";

  return h(
    tagName,
    {
      key: `list-${index}`,
      className: listClass
    },
    block.items.map((item, itemIndex) =>
      h("li", {
        key: `${tagName}-${itemIndex}`,
        dangerouslySetInnerHTML: {
          __html: renderInlineRichText(item)
        }
      })
    )
  );
}
