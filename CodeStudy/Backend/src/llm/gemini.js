/**
 * Gemini streaming LLM client.
 *
 * Uses native fetch — no npm dependencies.
 */

import { CONFIG } from '../config.js';

export class StreamInterruptedError extends Error {
  constructor(message = 'Stream interrupted') {
    super(message);
    this.name = 'StreamInterruptedError';
  }
}

/**
 * Convert our internal messages format to Gemini API contents format.
 *
 * @param {Array<{role: string, content: string}>} messages
 * @returns {Array<{role: string, parts: Array<{text: string}>}>}
 */
function toGeminiContents(messages) {
  return messages.map((m) => ({
    role: m.role === 'assistant' ? 'model' : 'user',
    parts: [{ text: m.content }],
  }));
}

/**
 * Parse a single SSE data line and extract text content.
 *
 * @param {string} line - Raw SSE line (after "data: " prefix)
 * @returns {string|null} Extracted text or null
 */
function extractTextFromSSE(line) {
  if (!line || line === '[DONE]') return null;
  try {
    const parsed = JSON.parse(line);
    const text = parsed?.candidates?.[0]?.content?.parts?.[0]?.text;
    return text || null;
  } catch {
    return null;
  }
}

/**
 * Stream chat completions from Gemini API.
 *
 * @param {Array<{role: string, content: string}>} messages
 * @param {string} systemPrompt
 * @param {object} [options]
 * @param {string} [options.model] - Gemini model name
 * @param {string} [options.apiKey] - API key override
 * @param {Function} [options.fetchImpl] - Custom fetch for testing
 * @yields {string} Text chunks
 */
export async function* streamGemini(messages, systemPrompt, options = {}) {
  const apiKey = options.apiKey || process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new Error(
      'GEMINI_API_KEY is not set. Provide it via environment variable or options.apiKey.',
    );
  }

  const model = options.model || CONFIG.GEMINI_MODEL;
  const fetchFn = options.fetchImpl || globalThis.fetch;

  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:streamGenerateContent` +
    `?alt=sse&key=${apiKey}`;

  const body = {
    contents: toGeminiContents(messages),
    systemInstruction: {
      parts: [{ text: systemPrompt }],
    },
    generationConfig: {
      temperature: 0.7,
      maxOutputTokens: 300,
    },
  };

  const response = await fetchFn(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    let errorBody = '';
    try {
      errorBody = await response.text();
    } catch {
      // ignore read errors
    }
    throw new Error(
      `Gemini API error: ${response.status} ${response.statusText} — ${errorBody}`,
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

      // Process complete SSE lines
      const lines = buffer.split('\n');
      // Keep the last (potentially incomplete) line in the buffer
      buffer = lines.pop() || '';

      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed.startsWith('data: ')) continue;

        const data = trimmed.slice(6); // strip "data: "
        const text = extractTextFromSSE(data);
        if (text) {
          yield text;
        }
      }
    }

    // Process any remaining data in the buffer
    if (buffer.trim().startsWith('data: ')) {
      const data = buffer.trim().slice(6);
      const text = extractTextFromSSE(data);
      if (text) {
        yield text;
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
