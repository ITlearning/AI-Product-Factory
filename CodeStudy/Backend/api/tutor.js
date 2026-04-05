import { CONFIG } from '../src/config.js';
import { validateTutorRequest } from '../src/validation.js';
import { checkRateLimit } from '../src/rate-limiter.js';
import { buildSystemPrompt } from '../src/prompts/socratic-rules.js';

const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models';

export default async function handler(req, options = {}) {
  const fetchImpl = options.fetchImpl || fetch;

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return new Response(JSON.stringify({ error: 'Server misconfiguration' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  let body;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const validation = validateTutorRequest(body);
  if (!validation.valid) {
    return new Response(JSON.stringify({ error: validation.error }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Rate limit by IP
  const ip =
    req.headers.get?.('x-forwarded-for')?.split(',')[0]?.trim() ||
    req.headers?.['x-forwarded-for']?.split(',')[0]?.trim() ||
    'unknown';
  const rateLimitResult = checkRateLimit(ip);
  if (!rateLimitResult.allowed) {
    return new Response(JSON.stringify({ error: 'Rate limit exceeded' }), {
      status: 429,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Turn limit: 40 messages = 20 pairs
  const { messages, conceptId, userProfile } = body;
  if (messages && messages.length > 40) {
    return new Response(
      JSON.stringify({ error: 'Turn limit exceeded. Start a new session.' }),
      {
        status: 429,
        headers: { 'Content-Type': 'application/json' },
      },
    );
  }

  // Bundle ID check
  const bundleId =
    req.headers.get?.('x-app-bundle-id') ||
    req.headers?.['x-app-bundle-id'] ||
    '';
  if (!CONFIG.ALLOWED_BUNDLE_IDS.includes(bundleId)) {
    return new Response(JSON.stringify({ error: 'Unauthorized client' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Build prompt and call Gemini
  const systemPrompt = buildSystemPrompt(
    conceptId,
    userProfile.level,
    userProfile.language,
  );
  const geminiMessages = (messages || []).map((m) => ({
    role: m.role === 'assistant' ? 'model' : 'user',
    parts: [{ text: m.content }],
  }));

  const geminiBody = {
    system_instruction: { parts: [{ text: systemPrompt }] },
    contents: geminiMessages,
    generationConfig: {
      temperature: 0.7,
      maxOutputTokens: 1024,
    },
  };

  const url = `${GEMINI_API_URL}/${CONFIG.GEMINI_MODEL}:streamGenerateContent?alt=sse&key=${apiKey}`;

  let upstream;
  try {
    upstream = await fetchImpl(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(geminiBody),
    });
  } catch (err) {
    return new Response(
      JSON.stringify({ error: 'Upstream LLM request failed' }),
      {
        status: 502,
        headers: { 'Content-Type': 'application/json' },
      },
    );
  }

  if (!upstream.ok) {
    return new Response(
      JSON.stringify({ error: 'Upstream LLM error', status: upstream.status }),
      {
        status: 502,
        headers: { 'Content-Type': 'application/json' },
      },
    );
  }

  // Stream SSE to client
  const reader = upstream.body.getReader();
  const decoder = new TextDecoder();
  let fullText = '';

  const stream = new ReadableStream({
    async start(controller) {
      const encoder = new TextEncoder();

      try {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;

          const chunk = decoder.decode(value, { stream: true });
          const lines = chunk.split('\n');

          for (const line of lines) {
            if (!line.startsWith('data: ')) continue;
            const jsonStr = line.slice(6).trim();
            if (!jsonStr || jsonStr === '[DONE]') continue;

            try {
              const parsed = JSON.parse(jsonStr);
              const text =
                parsed?.candidates?.[0]?.content?.parts?.[0]?.text || '';
              if (text) {
                fullText += text;
                // Strip [MASTERY] from displayed text
                const displayText = text.replace(/\[MASTERY\]/g, '');
                if (displayText) {
                  const sseData = `data: ${JSON.stringify({ t: displayText })}\n\n`;
                  controller.enqueue(encoder.encode(sseData));
                }
              }
            } catch {
              // Skip unparseable chunks
            }
          }
        }

        // Final message
        const mastered = fullText.includes('[MASTERY]');
        const finalData = `data: ${JSON.stringify({ done: true, mastered })}\n\n`;
        controller.enqueue(encoder.encode(finalData));
        controller.close();
      } catch (err) {
        controller.error(err);
      }
    },
  });

  return new Response(stream, {
    status: 200,
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
    },
  });
}
