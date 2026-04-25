import { CONFIG } from '../src/config.js';
import { validateTutorRequest } from '../src/validation.js';
import { checkRateLimit } from '../src/rate-limiter.js';
import { buildSystemPrompt } from '../src/prompts/socratic-rules.js';
import { streamChat } from '../src/llm/provider.js';
import { logConversation } from '../src/logger.js';

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
  // API key check — resolve the right env var for the configured provider
  const provider = CONFIG.DEFAULT_PROVIDER;
  const apiKeyEnvVar = {
    openrouter: 'OPENROUTER_API_KEY',
    claude: 'ANTHROPIC_API_KEY',
    gemini: 'GEMINI_API_KEY',
  }[provider] || 'OPENROUTER_API_KEY';
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

  const { messages, conceptId, userProfile, sessionId: bodySessionId } = body;

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
      status: 403,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // 로깅용 식별자. 헤더 → body → 'unknown' 순으로 fallback.
  const userId = req.headers.get('x-codestudy-userid') || 'unknown';
  const sessionId =
    req.headers.get('x-codestudy-sessionid') || bodySessionId || 'unknown';

  // Build system prompt — can throw if conceptId is not in curriculum
  let systemPrompt;
  try {
    systemPrompt = buildSystemPrompt(
      conceptId,
      userProfile.level,
      userProfile.language,
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: 'Invalid concept', detail: err.message }),
      {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      },
    );
  }

  // Handle the initial-message trigger: iOS sends "__START__" as the first
  // (and only) user message when ChatView appears. Replace it with an
  // explicit instruction so the AI produces a warm opening message.
  let effectiveMessages = messages || [];
  if (effectiveMessages.length === 1 && effectiveMessages[0].content === '__START__') {
    const startInstruction =
      userProfile.language === 'en'
        ? 'Start the session: warmly greet the student in one line, briefly introduce the concept (one sentence about WHY it matters), then ask your first Socratic opening question. Keep the whole response under 5 lines.'
        : '세션을 시작해주세요: 학습자에게 한 줄로 따뜻하게 인사하고, 이 개념이 왜 중요한지 한 문장으로 소개한 뒤, 첫 번째 소크라테스식 질문을 던져주세요. 전체 응답은 5줄 이내로 작성해주세요.';
    effectiveMessages = [{ role: 'user', content: startInstruction }];
  }

  // Stream LLM response and forward as SSE
  const encoder = new TextEncoder();
  let fullText = '';
  const startTime = Date.now();

  // 로깅용 메타데이터 — stream 안팎 모두에서 접근
  const modelByProvider = {
    openrouter: CONFIG.OPENROUTER_MODEL,
    claude: CONFIG.CLAUDE_MODEL,
    gemini: CONFIG.GEMINI_MODEL,
  };
  const modelName = modelByProvider[provider];
  // body.messages에서 마지막 user 메시지(원문) 추출.
  // effectiveMessages는 __START__가 치환된 경우가 있어 로그에 원문이 남도록.
  const originalMessages = messages || [];
  const lastUserMessage = [...originalMessages].reverse().find(m => m.role === 'user');
  const userInput = lastUserMessage ? lastUserMessage.content : '';
  const turnIndex = originalMessages.length;

  // streamChat 내부에서 usage 청크 도착 시 ref.value에 채워줌.
  // ref 패턴: stream 끝난 후 logConversation에서 읽기 위한 캡처 컨테이너.
  const usageRef = { value: null };

  const stream = new ReadableStream({
    async start(controller) {
      try {
        for await (const chunk of streamChat(effectiveMessages, systemPrompt, {
          provider,
          apiKey,
          model: modelName,
          onUsage: (u) => { usageRef.value = u; },
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

        // 성공 로그
        logConversation({
          event: 'turn',
          userId,
          sessionId,
          conceptId,
          turnIndex,
          userInput,
          aiOutput: fullText,
          mastered,
          model: modelName,
          provider,
          latencyMs: Date.now() - startTime,
          level: userProfile.level,
          language: userProfile.language,
          // OpenRouter 응답 마지막 SSE 청크의 usage. 비용 추적 + 토큰 카운트.
          //
          // Cache 참고: OpenRouter는 prompt_tokens_details.cached_tokens /
          // cache_write_tokens 필드로 cache hit/miss를 노출함. Haiku 4.5는
          // 시스템 프롬프트가 2048 토큰 미만이면 캐시 자체를 안 만들어서
          // 두 값 모두 0으로 들어옴. cache 검증은 향후 prompt 크기 늘릴 때.
          tokensIn: usageRef.value?.prompt_tokens ?? null,
          tokensOut: usageRef.value?.completion_tokens ?? null,
          costUsd: usageRef.value?.cost ?? null,
          usage: usageRef.value,
        });
      } catch (err) {
        // Upstream LLM failure — emit an error SSE event, then close.
        const errorData = `data: ${JSON.stringify({ error: 'stream_interrupted', message: err.message })}\n\n`;
        try {
          controller.enqueue(encoder.encode(errorData));
        } catch {
          // controller already closed
        }
        controller.close();

        // 에러 로그
        logConversation({
          event: 'error',
          userId,
          sessionId,
          conceptId,
          turnIndex,
          userInput,
          model: modelName,
          provider,
          latencyMs: Date.now() - startTime,
          level: userProfile.level,
          language: userProfile.language,
          errorCode: 'stream_interrupted',
          errorMessage: err.message,
        });
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
