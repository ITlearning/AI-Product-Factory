import { translateWithRules } from "./rule-engine.js";

export function translateWithFallback(input) {
  return translateWithRules(input);
}
