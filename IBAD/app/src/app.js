import { applyExample, createInitialState, startRequest, submitReplyRequest, updateField } from "./ui/state.js";
import { renderAppMarkup } from "./ui/templates.js";

/**
 * @param {HTMLElement} root
 * @param {{ requestReplySet?: typeof import("./api/generate-reply.js").requestReplySet }} [options]
 */
export function createApp(root, options = {}) {
  let state = createInitialState();

  function bindEvents() {
    const form = root.querySelector('[data-role="composer"]');
    const textarea = root.querySelector("#input-message");
    const situationSelect = root.querySelector("#situation-type");
    const exampleButtons = root.querySelectorAll("[data-example-index]");
    const copyButtons = root.querySelectorAll("[data-copy-reply]");

    if (
      !(form instanceof HTMLFormElement) ||
      !(textarea instanceof HTMLTextAreaElement) ||
      !(situationSelect instanceof HTMLSelectElement)
    ) {
      return;
    }

    textarea.addEventListener("input", (event) => {
      state = updateField(state, "input", /** @type {HTMLTextAreaElement} */ (event.currentTarget).value);
    });

    situationSelect.addEventListener("change", (event) => {
      state = updateField(
        state,
        "situationType",
        /** @type {HTMLSelectElement} */ (event.currentTarget).value
      );
    });

    for (const button of exampleButtons) {
      button.addEventListener("click", () => {
        state = applyExample(state, Number(button.getAttribute("data-example-index")));
        render();
      });
    }

    for (const button of copyButtons) {
      button.addEventListener("click", async () => {
        const text = button.getAttribute("data-copy-reply") ?? "";

        if (text && navigator?.clipboard?.writeText) {
          await navigator.clipboard.writeText(text).catch(() => {});
        }
      });
    }

    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      state = startRequest(state);
      render();
      state = await submitReplyRequest(state, {
        requestReplySet: options.requestReplySet
      });
      render();
      root.querySelector("#results")?.scrollIntoView({ behavior: "smooth", block: "start" });
    });
  }

  function render() {
    root.innerHTML = renderAppMarkup(state);
    bindEvents();
  }

  render();

  return {
    getState() {
      return state;
    }
  };
}
