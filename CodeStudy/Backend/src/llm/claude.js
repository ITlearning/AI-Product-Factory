/**
 * Claude (Anthropic) streaming LLM client.
 *
 * Uses native fetch — no npm dependencies.
 * Docs: https://docs.claude.com/en/api/messages-streaming
 */

import { CONFIG } from '../config.js';

export class StreamInterruptedError extends Error {
  constructor(message = 'Stream interrupted') {
    super(message);
    this.name = 'StreamInterruptedError';
  }
}

/**
 * Convert our internal messages format to Claude API messages format.
 * Claude uses "user" and "assistant" roles (same as our format).
 *
 * @param {Array<{role: string, content: string}>} messages
 * @returns {Array<{role: string, content: string}>}
 */
function toClaudeMessages(messages) {
  return messages
    .filter((m) => m.role === 'user' || m.role === 'assistant')
    .map((m) => ({
      role: m.role,
      content: m.content,
    }));
}

/**
 * Parse a single SSE event and extract text delta.
 * Claude streaming events: message_start, content_block_start,
 * content_block_delta, content_block_stop, message_delta, message_stop.
 * We only care about content_block_delta with text_delta.
 *
 * @param {string} eventData - JSON string from SSE data line
 * @returns {string|null} Extracted text delta or null
 */
function extractTextFromEvent(eventData) {
  if (!eventData) return null;
  try {
    const parsed = JSON.parse(eventData);
    if (
      parsed?.type === 'content_block_delta' &&
      parsed?.delta?.type === 'text_delta'
    ) {
      return parsed.delta.text || null;
    }
    return null;
  } catch {
    return null;
  }
}

/**
 * Stream chat completions from Claude API.
 *
 * @param {Array<{role: string, content: string}>} messages
 * @param {string} systemPrompt
 * @param {object} [options]
 * @param {string} [options.model] - Claude model name
 * @param {string} [options.apiKey] - API key override
 * @param {Function} [options.fetchImpl] - Custom fetch for testing
 * @yields {string} Text chunks
 */
export async function* streamClaude(messages, systemPrompt, options = {}) {
  const apiKey = options.apiKey || process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    throw new Error(
      'ANTHROPIC_API_KEY is not set. Provide it via environment variable or options.apiKey.',
    );
  }

  const model = options.model || CONFIG.CLAUDE_MODEL;
  const fetchFn = options.fetchImpl || globalThis.fetch;

  const url = 'https://api.anthropic.com/v1/messages';

  const body = {
    model,
    max_tokens: 500,
    temperature: 0.7,
    system: systemPrompt,
    messages: toClaudeMessages(messages),
    stream: true,
  };

  const response = await fetchFn(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    let errorBody = '';
    try {
      errorBody = await response.text();
    } catch {
      // ignore
    }
    throw new Error(
      `Claude API error: ${response.status} ${response.statusText} — ${errorBody}`,
    );
  }

  const reader = response.body?.getReader();
  if (!reader) {
    throw new StreamInterruptedError('Response body is not readable');
  }

  const decoder = new TextDecoder();
  let buffer = '';

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });

      // SSE events separated by double newlines; lines prefixed with "data: "
      const lines = buffer.split('\n');
      buffer = lines.pop() || '';

      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed.startsWith('data: ')) continue;

        const data = trimmed.slice(6);
        if (data === '[DONE]') continue;

        const text = extractTextFromEvent(data);
        if (text) {
          yield text;
        }
      }
    }

    // Flush remaining buffer
    if (buffer.trim().startsWith('data: ')) {
      const data = buffer.trim().slice(6);
      if (data !== '[DONE]') {
        const text = extractTextFromEvent(data);
        if (text) {
          yield text;
        }
      }
    }
  } catch (error) {
    if (error instanceof StreamInterruptedError) throw error;
    throw new StreamInterruptedError(
      `Stream interrupted: ${error.message}`,
    );
  } finally {
    reader.releaseLock();
  }
}
