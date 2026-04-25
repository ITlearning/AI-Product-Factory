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

  // Prompt caching — Anthropic 모델일 때만 system 프롬프트에 cache_control 적용.
  //
  // OpenRouter는 Anthropic 계열에서 5분 ephemeral cache를 지원
  // (https://openrouter.ai/docs/features/prompt-caching).
  // OpenAI 모델은 자동 cache라서 cache_control 불필요.
  // Gemini 등 비지원 provider에 cache_control을 보내면 그냥 무시되거나
  // 400 에러가 나므로 모델명으로 분기.
  //
  // 캐시 대상: system prompt (가장 크고 turn마다 동일).
  // 비캐시: user/assistant 메시지 (매 턴 변동).
  const isAnthropic = model.startsWith('anthropic/');
  const systemMessage = isAnthropic
    ? {
        role: 'system',
        content: [
          {
            type: 'text',
            text: systemPrompt,
            cache_control: { type: 'ephemeral' },
          },
        ],
      }
    : { role: 'system', content: systemPrompt };

  // OpenAI-compatible request body
  const body = {
    model,
    stream: true,
    temperature: 0.7,
    max_tokens: 500,
    // OpenRouter usage 통계(prompt_tokens, cache_creation_input_tokens,
    // cache_read_input_tokens 등)을 응답 끝 SSE 청크에 포함시켜 줌.
    usage: { include: true },
    messages: [
      systemMessage,
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
          // 마지막 chunk에 usage가 포함됨 (usage.include=true 설정 시).
          // cache hit 검증용 — Vercel logs에서 grep 가능.
          if (parsed?.usage) {
            console.log(
              `codestudy.usage ${JSON.stringify({ model, usage: parsed.usage })}`,
            );
            // caller에게도 usage 전달 (logConversation의 prompt_tokens 등 채우기용).
            // try/catch — 콜백이 throw해도 stream 진행 보장.
            if (typeof options.onUsage === 'function') {
              try { options.onUsage(parsed.usage); } catch { /* ignore */ }
            }
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
          if (parsed?.usage) {
            console.log(
              `codestudy.usage ${JSON.stringify({ model, usage: parsed.usage })}`,
            );
            // caller에게도 usage 전달 (logConversation의 prompt_tokens 등 채우기용).
            // try/catch — 콜백이 throw해도 stream 진행 보장.
            if (typeof options.onUsage === 'function') {
              try { options.onUsage(parsed.usage); } catch { /* ignore */ }
            }
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
