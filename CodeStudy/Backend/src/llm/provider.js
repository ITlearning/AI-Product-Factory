/**
 * LLM provider abstraction layer.
 *
 * Routes to the correct provider-specific streaming implementation.
 * Default provider: OpenRouter (supports 400+ models via one API key).
 */

import { streamOpenRouter } from './openrouter.js';
import { streamClaude } from './claude.js';
import { streamGemini } from './gemini.js';

/**
 * Stream chat completions from the configured LLM provider.
 *
 * @param {Array<{role: string, content: string}>} messages
 * @param {string} systemPrompt
 * @param {object} [options]
 * @param {'openrouter'|'claude'|'gemini'} [options.provider='openrouter'] - LLM provider
 * @param {string} [options.model] - Model override
 * @param {string} [options.apiKey] - API key override
 * @param {Function} [options.fetchImpl] - Custom fetch for testing
 * @yields {string} Text chunks
 */
export async function* streamChat(messages, systemPrompt, options = {}) {
  const provider = options.provider || 'openrouter';

  switch (provider) {
    case 'openrouter':
      yield* streamOpenRouter(messages, systemPrompt, options);
      break;
    case 'claude':
      yield* streamClaude(messages, systemPrompt, options);
      break;
    case 'gemini':
      yield* streamGemini(messages, systemPrompt, options);
      break;
    default:
      throw new Error(`Unknown provider: ${provider}`);
  }
}
