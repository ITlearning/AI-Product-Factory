import { CONFIG } from '../src/config.js';
import { validateTutorRequest } from '../src/validation.js';
import { checkRateLimit } from '../src/rate-limiter.js';
import { buildSystemPrompt } from '../src/prompts/socratic-rules.js';
import { streamChat } from '../src/llm/provider.js';

/**
 * POST /api/tutor — Socratic tutor chat endpoint.
 *
 * Forwards a streaming LLM response as SSE to the client.
 * Each chunk: `data: {"t":"텍스트"}\n\n`
 * Final chunk:  `data: {"done":true,"mastered":boolean}\n\n`
 *
 * The [MASTERY] marker is stripped from displayed text and reported
 * via the `mastered` flag in the final chunk.
 */
export async function POST(req) {
  // API key check (Claude by default, Gemini for fallback)
  const provider = CONFIG.DEFAULT_PROVIDER;
  const apiKeyEnvVar =
    provider === 'claude' ? 'ANTHROPIC_API_KEY' : 'GEMINI_API_KEY';
  const apiKey = process.env[apiKeyEnvVar];
  if (!apiKey) {
    return new Response(
      JSON.stringify({
        error: 'Server misconfiguration',
        detail: `${apiKeyEnvVar} not set`,
      }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      },
    );
  }

  // Parse body
  let body;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Validate body
  const validation = validateTutorRequest(body);
  if (!validation.valid) {
    return new Response(JSON.stringify({ error: validation.error }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Rate limit by IP
  const ip =
    req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() || 'unknown';
  const rateLimitResult = checkRateLimit(ip);
  if (!rateLimitResult.allowed) {
    return new Response(JSON.stringify({ error: 'Rate limit exceeded' }), {
      status: 429,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const { messages, conceptId, userProfile } = body;

  // Turn limit: 40 messages = 20 pairs
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
  const bundleId = req.headers.get('x-app-bundle-id') || '';
  if (!CONFIG.ALLOWED_BUNDLE_IDS.includes(bundleId)) {
    return new Response(JSON.stringify({ error: 'Unauthorized client' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Build system prompt
  const systemPrompt = buildSystemPrompt(
    conceptId,
    userProfile.level,
    userProfile.language,
  );

  // Stream LLM response and forward as SSE
  const encoder = new TextEncoder();
  let fullText = '';

  const stream = new ReadableStream({
    async start(controller) {
      try {
        for await (const chunk of streamChat(messages || [], systemPrompt, {
          provider,
          apiKey,
        })) {
          fullText += chunk;
          // Strip [MASTERY] from displayed text
          const displayText = chunk.replace(/\[MASTERY\]/g, '');
          if (displayText) {
            const sseData = `data: ${JSON.stringify({ t: displayText })}\n\n`;
            controller.enqueue(encoder.encode(sseData));
          }
        }

        // Final message
        const mastered = fullText.includes('[MASTERY]');
        const finalData = `data: ${JSON.stringify({ done: true, mastered })}\n\n`;
        controller.enqueue(encoder.encode(finalData));
        controller.close();
      } catch (err) {
        // Upstream LLM failure — emit an error SSE event, then close.
        const errorData = `data: ${JSON.stringify({ error: 'stream_interrupted', message: err.message })}\n\n`;
        try {
          controller.enqueue(encoder.encode(errorData));
        } catch {
          // controller already closed
        }
        controller.close();
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
