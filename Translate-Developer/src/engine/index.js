import { translateWithFallback } from "./fallback-engine.js";
import { translateWithRules } from "./rule-engine.js";
import {
  isValidTermExplanation,
  isValidTranslationResult,
  normalizeTranslationResult,
  TRANSLATION_JSON_SCHEMA
} from "./schema.js";

export {
  isValidTermExplanation,
  isValidTranslationResult,
  normalizeTranslationResult,
  TRANSLATION_JSON_SCHEMA,
  translateWithFallback,
  translateWithRules
};

export const ruleEngine = {
  translate: translateWithRules
};

export const fallbackEngine = {
  translate: translateWithFallback
};
