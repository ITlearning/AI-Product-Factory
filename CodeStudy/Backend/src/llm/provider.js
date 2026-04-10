/**
 * LLM provider abstraction layer.
 *
 * Routes to the correct provider-specific streaming implementation.
 * Default provider: Claude (Anthropic).
 */

import { streamClaude } from './claude.js';
import { streamGemini } from './gemini.js';

/**
 * Stream chat completions from the configured LLM provider.
 *
 * @param {Array<{role: string, content: string}>} messages
 * @param {string} systemPrompt
 * @param {object} [options]
 * @param {'claude'|'gemini'} [options.provider='claude'] - LLM provider
 * @param {string} [options.model] - Model override
 * @param {string} [options.apiKey] - API key override
 * @param {Function} [options.fetchImpl] - Custom fetch for testing
 * @yields {string} Text chunks
 */
export async function* streamChat(messages, systemPrompt, options = {}) {
  const provider = options.provider || 'claude';

  switch (provider) {
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
