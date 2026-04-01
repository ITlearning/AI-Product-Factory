import React from "react";

import { EXAMPLE_MESSAGES } from "./data/examples.js";
import { useTranslatorApp } from "./hooks/useTranslatorApp.js";
import { AppShell } from "./components/AppShell.js";

const { createElement: h } = React;

/**
 * @param {{
 *   requestTranslation?: typeof import("./api/translate.js").requestAiTranslation,
 *   fallbackEngine?: (input: string, audience: import("./engine/types.js").AudienceId) => import("./engine/types.js").TranslationResult,
 *   initialState?: import("./ui/state.js").AppState
 * }} [options]
 */
export function App(options = {}) {
  const {
    state,
    selectedAudience,
    resultsRef,
    handleAudienceChange,
    handleExampleSelect,
    handleInputChange,
    handleSubmit
  } = useTranslatorApp(options);

  return h(AppShell, {
    examples: EXAMPLE_MESSAGES.developer,
    onInputChange: handleInputChange,
    onSelectAudience: handleAudienceChange,
    onSelectExample: handleExampleSelect,
    onSubmit: handleSubmit,
    resultsRef,
    selectedAudience,
    state
  });
}
