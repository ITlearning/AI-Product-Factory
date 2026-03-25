import { translateWithRules } from "./rule-engine.js";

/**
 * @param {string} input
 * @param {import("./types.js").AudienceId} [audience]
 */
export function translateWithFallback(input, audience = "pm-planner") {
  return translateWithRules(input, audience);
}
