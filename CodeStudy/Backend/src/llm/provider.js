/**
 * LLM provider abstraction layer.
 *
 * Routes to the correct provider-specific streaming implementation.
 */

import { streamGemini } from './gemini.js';

/**
 * Stream chat completions from the configured LLM provider.
 *
 * @param {Array<{role: string, content: string}>} messages
 * @param {string} systemPrompt
 * @param {object} [options]
 * @param {'gemini'} [options.provider='gemini'] - LLM provider
 * @param {string} [options.model] - Model override
 * @param {string} [options.apiKey] - API key override
 * @param {Function} [options.fetchImpl] - Custom fetch for testing
 * @yields {string} Text chunks
 */
export async function* streamChat(messages, systemPrompt, options = {}) {
  const provider = options.provider || 'gemini';

  switch (provider) {
    case 'gemini':
      yield* streamGemini(messages, systemPrompt, options);
      break;
    default:
      throw new Error(`Unknown provider: ${provider}`);
  }
}
