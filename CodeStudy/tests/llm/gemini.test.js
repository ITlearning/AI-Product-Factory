import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { streamGemini, StreamInterruptedError } from '../../src/llm/gemini.js';

/**
 * Create a mock fetch that returns SSE-formatted streaming response.
 *
 * @param {string[]} chunks - Array of text chunks to stream
 * @param {number} [status=200] - HTTP status code
 * @param {string} [statusText='OK'] - HTTP status text
 * @returns {Function} Mock fetch implementation
 */
function createMockFetch(chunks, status = 200, statusText = 'OK') {
  return async () => {
    if (status !== 200) {
      return {
        ok: false,
        status,
        statusText,
        text: async () => JSON.stringify({ error: { message: 'Rate limit exceeded' } }),
      };
    }

    // Build SSE data from chunks
    const sseLines = chunks.map((text) => {
      const payload = {
        candidates: [
          {
            content: {
              parts: [{ text }],
              role: 'model',
            },
          },
        ],
      };
      return `data: ${JSON.stringify(payload)}\n\n`;
    });

    const fullSSE = sseLines.join('');
    const encoded = new TextEncoder().encode(fullSSE);
    let read = false;

    const reader = {
      read: async () => {
        if (!read) {
          read = true;
          return { done: false, value: encoded };
        }
        return { done: true, value: undefined };
      },
      releaseLock: () => {},
    };

    return {
      ok: true,
      status: 200,
      statusText: 'OK',
      body: { getReader: () => reader },
    };
  };
}

/**
 * Collect all chunks from an async generator into an array.
 */
async function collectChunks(generator) {
  const chunks = [];
  for await (const chunk of generator) {
    chunks.push(chunk);
  }
  return chunks;
}

const SAMPLE_MESSAGES = [
  { role: 'user', content: 'What is an optional?' },
];
const SAMPLE_SYSTEM = 'You are a tutor.';
const BASE_OPTIONS = { apiKey: 'test-key' };

describe('streamGemini', () => {
  it('streams text chunks from SSE response', async () => {
    const mockFetch = createMockFetch(['Hello, ', 'world!']);
    const chunks = await collectChunks(
      streamGemini(SAMPLE_MESSAGES, SAMPLE_SYSTEM, {
        ...BASE_OPTIONS,
        fetchImpl: mockFetch,
      }),
    );

    assert.deepEqual(chunks, ['Hello, ', 'world!']);
  });

  it('sends correct request body to Gemini API', async () => {
    let capturedUrl;
    let capturedBody;

    const mockFetch = async (url, init) => {
      capturedUrl = url;
      capturedBody = JSON.parse(init.body);

      const encoded = new TextEncoder().encode('data: {"candidates":[]}\n\n');
      let read = false;
      return {
        ok: true,
        status: 200,
        body: {
          getReader: () => ({
            read: async () => {
              if (!read) {
                read = true;
                return { done: false, value: encoded };
              }
              return { done: true };
            },
            releaseLock: () => {},
          }),
        },
      };
    };

    await collectChunks(
      streamGemini(SAMPLE_MESSAGES, SAMPLE_SYSTEM, {
        ...BASE_OPTIONS,
        fetchImpl: mockFetch,
      }),
    );

    // Verify URL includes SSE param and model
    assert.ok(capturedUrl.includes('alt=sse'));
    assert.ok(capturedUrl.includes('gemini-2.0-flash-lite'));

    // Verify body structure
    assert.ok(capturedBody.systemInstruction);
    assert.equal(capturedBody.systemInstruction.parts[0].text, SAMPLE_SYSTEM);
    assert.equal(capturedBody.contents[0].role, 'user');
    assert.equal(capturedBody.contents[0].parts[0].text, 'What is an optional?');
    assert.equal(capturedBody.generationConfig.temperature, 0.7);
    assert.equal(capturedBody.generationConfig.maxOutputTokens, 300);
  });

  it('converts assistant role to model role', async () => {
    let capturedBody;
    const mockFetch = async (_url, init) => {
      capturedBody = JSON.parse(init.body);
      const encoded = new TextEncoder().encode('data: {"candidates":[]}\n\n');
      let read = false;
      return {
        ok: true,
        status: 200,
        body: {
          getReader: () => ({
            read: async () => {
              if (!read) {
                read = true;
                return { done: false, value: encoded };
              }
              return { done: true };
            },
            releaseLock: () => {},
          }),
        },
      };
    };

    const messages = [
      { role: 'user', content: 'Hi' },
      { role: 'assistant', content: 'Hello' },
      { role: 'user', content: 'What is Swift?' },
    ];

    await collectChunks(
      streamGemini(messages, SAMPLE_SYSTEM, {
        ...BASE_OPTIONS,
        fetchImpl: mockFetch,
      }),
    );

    assert.equal(capturedBody.contents[1].role, 'model');
  });

  it('throws when API key is missing', async () => {
    // Temporarily clear env
    const original = process.env.GEMINI_API_KEY;
    delete process.env.GEMINI_API_KEY;

    try {
      await assert.rejects(
        async () => {
          const gen = streamGemini(SAMPLE_MESSAGES, SAMPLE_SYSTEM, {
            fetchImpl: createMockFetch([]),
          });
          await gen.next();
        },
        /GEMINI_API_KEY is not set/,
      );
    } finally {
      if (original !== undefined) {
        process.env.GEMINI_API_KEY = original;
      }
    }
  });

  it('throws on non-200 API response (e.g., 429)', async () => {
    const mockFetch = createMockFetch([], 429, 'Too Many Requests');

    await assert.rejects(
      async () => {
        const gen = streamGemini(SAMPLE_MESSAGES, SAMPLE_SYSTEM, {
          ...BASE_OPTIONS,
          fetchImpl: mockFetch,
        });
        await gen.next();
      },
      /Gemini API error: 429/,
    );
  });

  it('handles empty SSE data gracefully', async () => {
    const mockFetch = async () => {
      const sseData = 'data: [DONE]\n\ndata: \n\n';
      const encoded = new TextEncoder().encode(sseData);
      let read = false;

      return {
        ok: true,
        status: 200,
        body: {
          getReader: () => ({
            read: async () => {
              if (!read) {
                read = true;
                return { done: false, value: encoded };
              }
              return { done: true };
            },
            releaseLock: () => {},
          }),
        },
      };
    };

    const chunks = await collectChunks(
      streamGemini(SAMPLE_MESSAGES, SAMPLE_SYSTEM, {
        ...BASE_OPTIONS,
        fetchImpl: mockFetch,
      }),
    );

    assert.deepEqual(chunks, []);
  });

  it('exports StreamInterruptedError', () => {
    const err = new StreamInterruptedError('test');
    assert.equal(err.name, 'StreamInterruptedError');
    assert.ok(err instanceof Error);
  });
});
