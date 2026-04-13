/**
 * OpenRouter streaming LLM client.
 *
 * OpenRouter implements the OpenAI Chat Completions API spec, so request/
 * response format is identical to OpenAI. We just change the endpoint URL
 * and auth header.
 *
 * Docs: https://openrouter.ai/docs/quickstart
 */

import { StreamInterruptedError } from './claude.js';

/**
 * Stream chat completions from OpenRouter API.
 *
 * @param {Array<{role: string, content: string}>} messages
 * @param {string} systemPrompt
 * @param {object} [options]
 * @param {string} [options.model] - OpenRouter model ID (e.g. 'openai/gpt-4.1-mini')
 * @param {string} [options.apiKey] - API key override
 * @param {Function} [options.fetchImpl] - Custom fetch for testing
 * @yields {string} Text chunks
 */
export async function* streamOpenRouter(messages, systemPrompt, options = {}) {
  const apiKey = options.apiKey || process.env.OPENROUTER_API_KEY;
  if (!apiKey) {
    throw new Error(
      'OPENROUTER_API_KEY is not set. Provide it via environment variable or options.apiKey.',
    );
  }

  const model = options.model || 'openai/gpt-4.1-mini';
  const fetchFn = options.fetchImpl || globalThis.fetch;

  const url = 'https://openrouter.ai/api/v1/chat/completions';

  // OpenAI-compatible request body
  const body = {
    model,
    stream: true,
    temperature: 0.7,
    max_tokens: 500,
    messages: [
      { role: 'system', content: systemPrompt },
      ...messages.map((m) => ({
        role: m.role === 'assistant' ? 'assistant' : 'user',
        content: m.content,
      })),
    ],
  };

  const response = await fetchFn(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
      'HTTP-Referer': 'https://codestudy-nine.vercel.app',
      'X-Title': 'CodeStudy',
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
      `OpenRouter API error: ${response.status} ${response.statusText} — ${errorBody}`,
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

      const lines = buffer.split('\n');
      buffer = lines.pop() || '';

      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed.startsWith('data: ')) continue;

        const data = trimmed.slice(6);
        if (data === '[DONE]') continue;

        try {
          const parsed = JSON.parse(data);
          // OpenAI-compatible streaming: delta.content
          const text = parsed?.choices?.[0]?.delta?.content;
          if (text) {
            yield text;
          }
        } catch {
          // skip unparseable chunks
        }
      }
    }

    // Flush remaining buffer
    if (buffer.trim().startsWith('data: ')) {
      const data = buffer.trim().slice(6);
      if (data !== '[DONE]') {
        try {
          const parsed = JSON.parse(data);
          const text = parsed?.choices?.[0]?.delta?.content;
          if (text) {
            yield text;
          }
        } catch {
          // skip
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
