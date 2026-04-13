export const CONFIG = {
  MAX_SESSIONS_PER_DAY: 5,
  MAX_TURNS_PER_SESSION: 20,
  RATE_LIMIT_PER_MINUTE: 10,
  ALLOWED_BUNDLE_IDS: [
    'com.itlearning.codestudy',
    'com.itlearning.codestudy.CodeStudy',
  ],
  // LLM provider: 'openrouter' (default), 'claude', 'gemini'
  DEFAULT_PROVIDER: process.env.LLM_PROVIDER || 'openrouter',
  // OpenRouter model — set via env var OPENROUTER_MODEL in Vercel Dashboard.
  // Change it without redeploying!
  // Options:
  //   openai/gpt-4.1-mini          $0.40/$1.60 — best instruction following
  //   openai/gpt-4.1-nano          $0.10/$0.40 — cheapest
  //   google/gemma-4-31b-it        $0.14/$0.40 — open model
  //   google/gemma-4-31b-it:free   $0/$0 (rate limited)
  //   anthropic/claude-haiku-4.5   $1/$5 — best quality
  //   deepseek/deepseek-chat-v3.2  $0.14/$0.28
  OPENROUTER_MODEL: process.env.OPENROUTER_MODEL || 'openai/gpt-4.1-mini',
  // Legacy direct providers
  CLAUDE_MODEL: 'claude-haiku-4-5-20251001',
  GEMINI_MODEL: 'gemini-2.0-flash-lite',
};
