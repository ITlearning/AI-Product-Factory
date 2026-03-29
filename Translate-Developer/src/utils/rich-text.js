import { escapeHtml } from "./text.js";

/**
 * @param {string} value
 * @returns {Array<
 *   | { type: "paragraph", lines: string[] }
 *   | { type: "ul" | "ol", items: string[] }
 * >}
 */
export function parseRichTextBlocks(value) {
  const blocks = [];
  const lines = value.replace(/\r\n?/g, "\n").split("\n");
  let paragraphLines = [];
  let listBlock = null;

  function flushParagraph() {
    if (paragraphLines.length === 0) {
      return;
    }

    blocks.push({ type: "paragraph", lines: paragraphLines });
    paragraphLines = [];
  }

  function flushList() {
    if (!listBlock || listBlock.items.length === 0) {
      listBlock = null;
      return;
    }

    blocks.push(listBlock);
    listBlock = null;
  }

  for (const rawLine of lines) {
    const line = rawLine.trim();

    if (!line) {
      flushParagraph();
      flushList();
      continue;
    }

    const unorderedMatch = rawLine.match(/^\s*[-*]\s+(.+)$/);
    const orderedMatch = rawLine.match(/^\s*\d+\.\s+(.+)$/);

    if (unorderedMatch) {
      flushParagraph();

      if (!listBlock || listBlock.type !== "ul") {
        flushList();
        listBlock = { type: "ul", items: [] };
      }

      listBlock.items.push(unorderedMatch[1].trim());
      continue;
    }

    if (orderedMatch) {
      flushParagraph();

      if (!listBlock || listBlock.type !== "ol") {
        flushList();
        listBlock = { type: "ol", items: [] };
      }

      listBlock.items.push(orderedMatch[1].trim());
      continue;
    }

    flushList();
    paragraphLines.push(line);
  }

  flushParagraph();
  flushList();

  return blocks.length > 0 ? blocks : [{ type: "paragraph", lines: [value] }];
}

/**
 * @param {string} value
 * @returns {string}
 */
export function renderInlineRichText(value) {
  return escapeHtml(value)
    .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
    .replace(/`([^`]+)`/g, "<code>$1</code>");
}
