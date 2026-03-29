import React from "react";

import { getAudienceOption } from "../data/audiences.js";
import { createInitialState, updateAudience, updateInput, applyExample, startTranslation, submitTranslationAsync } from "../ui/state.js";

const { useEffect, useEffectEvent, useRef, useState } = React;

/**
 * @param {{
 *   requestTranslation?: typeof import("../api/translate.js").requestAiTranslation,
 *   fallbackEngine?: (input: string, audience: import("../engine/types.js").AudienceId) => import("../engine/types.js").TranslationResult,
 *   initialState?: import("../ui/state.js").AppState
 * }} [options]
 */
export function useTranslatorApp(options = {}) {
  const [state, setState] = useState(() => options.initialState ?? createInitialState());
  const [shouldRevealResults, setShouldRevealResults] = useState(false);
  const resultsRef = useRef(null);
  const stateRef = useRef(state);

  useEffect(() => {
    stateRef.current = state;
  }, [state]);

  useEffect(() => {
    if (!shouldRevealResults) {
      return;
    }

    resultsRef.current?.scrollIntoView({ behavior: "smooth", block: "start" });
    setShouldRevealResults(false);
  }, [shouldRevealResults]);

  const handleInputChange = useEffectEvent((nextValue) => {
    setState((currentState) => updateInput(currentState, nextValue));
  });

  const handleAudienceChange = useEffectEvent((audience) => {
    setState((currentState) => updateAudience(currentState, audience));
  });

  const handleExampleSelect = useEffectEvent((example) => {
    setState((currentState) => applyExample(currentState, example));
  });

  const handleSubmit = useEffectEvent(async (event) => {
    event.preventDefault();

    const loadingState = startTranslation(stateRef.current);
    setState(loadingState);

    const nextState = await submitTranslationAsync(loadingState, {
      requestTranslation: options.requestTranslation,
      fallbackEngine: options.fallbackEngine
    });

    setState(nextState);
    setShouldRevealResults(true);
  });

  return {
    state,
    selectedAudience: getAudienceOption(state.audience),
    resultsRef,
    handleAudienceChange,
    handleExampleSelect,
    handleInputChange,
    handleSubmit
  };
}
