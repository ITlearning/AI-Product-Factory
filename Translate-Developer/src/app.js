import { DEFAULT_EXAMPLE, EXAMPLE_MESSAGES } from "./data/examples.js";
import {
  applyExample,
  createInitialState,
  startTranslation,
  submitTranslationAsync,
  updateInput
} from "./ui/state.js";
import { renderAppMarkup } from "./ui/templates.js";

/**
 * @param {HTMLElement} root
 * @param {{
 *   requestTranslation?: typeof import("./api/translate.js").requestAiTranslation,
 *   fallbackEngine?: (input: string) => import("./engine/types.js").TranslationResult
 * }} [options]
 */
export function createApp(root, options = {}) {
  let state = createInitialState();
  let shouldRevealResults = false;

  function bindEvents() {
    const form = root.querySelector('[data-role="composer"]');
    const textarea = root.querySelector("#developer-message");
    const exampleButton = root.querySelector('[data-action="example"]');
    const exampleChips = root.querySelectorAll("[data-example-index]");

    if (!(form instanceof HTMLFormElement) || !(textarea instanceof HTMLTextAreaElement)) {
      return;
    }

    textarea.addEventListener("input", (event) => {
      const nextValue = /** @type {HTMLTextAreaElement} */ (event.currentTarget).value;
      state = updateInput(state, nextValue);
    });

    exampleButton?.addEventListener("click", () => {
      state = applyExample(state, DEFAULT_EXAMPLE);
      render();
    });

    for (const chip of exampleChips) {
      chip.addEventListener("click", () => {
        const index = Number(chip.getAttribute("data-example-index"));
        const message = EXAMPLE_MESSAGES[index] ?? DEFAULT_EXAMPLE;
        state = applyExample(state, message);
        render();
      });
    }

    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      state = startTranslation(state);
      render();
      state = await submitTranslationAsync(state, {
        requestTranslation: options.requestTranslation,
        fallbackEngine: options.fallbackEngine
      });
      shouldRevealResults = true;
      render();
    });
  }

  function render() {
    root.innerHTML = renderAppMarkup(state, {
      defaultExample: DEFAULT_EXAMPLE,
      examples: EXAMPLE_MESSAGES
    });
    bindEvents();

    if (shouldRevealResults) {
      const results = root.querySelector("#results");
      results?.scrollIntoView({ behavior: "smooth", block: "start" });
      shouldRevealResults = false;
    }
  }

  render();

  return {
    getState() {
      return state;
    }
  };
}
