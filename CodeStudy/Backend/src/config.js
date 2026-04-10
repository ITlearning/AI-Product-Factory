export const CONFIG = {
  MAX_SESSIONS_PER_DAY: 5,
  MAX_TURNS_PER_SESSION: 20,
  RATE_LIMIT_PER_MINUTE: 10,
  ALLOWED_BUNDLE_IDS: ['com.itlearning.codestudy'],
  // Default LLM provider
  DEFAULT_PROVIDER: 'claude',
  // Claude Haiku 4.5 — fast, cheap, capable
  CLAUDE_MODEL: 'claude-haiku-4-5-20251001',
  // Gemini fallback
  GEMINI_MODEL: 'gemini-2.0-flash-lite',
};
