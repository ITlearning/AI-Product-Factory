import { DEFAULT_OPENAI_MODEL, OPENAI_RESPONSES_URL } from "../src/config.js";
import { REPLY_JSON_SCHEMA, normalizeReplyResult } from "../src/domain/schema.js";
import { detectUnsupportedScope, findReplySafetyIssues } from "../src/domain/safety.js";
import { validateRequestPayload } from "../src/utils/validation.js";

const SYSTEM_PROMPT = [
  "당신은 한국어 거절 답장을 만들어 주는 어시스턴트다.",
  "목표는 예의를 지키되 애매한 여지를 남기지 않는 답장 3개를 주는 것이다.",
  "관계와 상황에 맞게 어조를 조절하되 공격적이거나 비꼬지 않는다.",
  "대안이 꺼져 있으면 다음에 보자, 나중에 보자, 시간 되면 같은 표현을 쓰지 않는다.",
  "장황한 변명은 줄이고 바로 보낼 수 있는 길이로 작성한다.",
  "반드시 지정된 JSON 스키마만 반환한다."
].join(" ");

/**
 * @param {Request | { method?: string, json?: () => Promise<unknown>, body?: unknown }} request
 * @param {{ fetchImpl?: typeof fetch, apiKey?: string, model?: string }} [options]
 * @returns {Promise<Response>}
 */
export async function handleGenerateReplyRequest(request, options = {}) {
  if ((request.method ?? "POST").toUpperCase() !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const body = await readRequestBody(request);
  const validation = validateRequestPayload(body);

  if (!validation.ok) {
    return jsonResponse({ error: validation.message }, 400);
  }

  const payload = validation.value;
  const scopeVerdict = detectUnsupportedScope(payload);

  if (!scopeVerdict.supported) {
    return jsonResponse(
      {
        error: scopeVerdict.message,
        code: scopeVerdict.code
      },
      422
    );
  }

  const apiKey = options.apiKey ?? process.env.OPENAI_API_KEY;

  if (!apiKey) {
    return jsonResponse({ error: "OPENAI_API_KEY is not configured." }, 500);
  }

  const fetchImpl = options.fetchImpl ?? fetch;
  const model = options.model ?? process.env.OPENAI_MODEL ?? DEFAULT_OPENAI_MODEL;

  try {
    const upstreamResponse = await fetchImpl(OPENAI_RESPONSES_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        model,
        input: [
          {
            role: "system",
            content: [{ type: "input_text", text: SYSTEM_PROMPT }]
          },
          {
            role: "user",
            content: [{ type: "input_text", text: buildUserPrompt(payload) }]
          }
        ],
        text: {
          format: {
            type: "json_schema",
            name: REPLY_JSON_SCHEMA.name,
            schema: REPLY_JSON_SCHEMA.schema,
            strict: true
          }
        }
      })
    });

    if (!upstreamResponse.ok) {
      return jsonResponse({ error: "AI upstream request failed." }, 502);
    }

    const upstreamPayload = await upstreamResponse.json();
    const normalized = extractStructuredResult(upstreamPayload);

    if (!normalized) {
      return jsonResponse(
        {
          error: "AI returned an invalid result.",
          code: "INVALID_AI_SCHEMA"
        },
        502
      );
    }

    for (const option of normalized.replyOptions) {
      const issues = findReplySafetyIssues(option.text, {
        includeAlternative: payload.includeAlternative
      });

      if (issues.length > 0) {
        return jsonResponse(
          {
            error: "AI returned an unsafe result.",
            code: "UNSAFE_RESULT"
          },
          502
        );
      }
    }

    return jsonResponse({ result: normalized, source: "ai" }, 200);
  } catch {
    return jsonResponse({ error: "AI request failed." }, 502);
  }
}

/**
 * @param {{
 *   input: string,
 *   relationshipType: string,
 *   situationType: string,
 *   rejectionStrength: string,
 *   includeAlternative: boolean
 * }} payload
 * @returns {string}
 */
export function buildUserPrompt(payload) {
  return [
    "다음 정보를 바탕으로 거절 답장 3개를 생성해 주세요.",
    `받은 메시지/상황: ${payload.input}`,
    `관계 타입: ${payload.relationshipType}`,
    `상황 타입: ${payload.situationType}`,
    `거절 강도: ${payload.rejectionStrength}`,
    `대안 제시 여부: ${payload.includeAlternative ? "한다" : "안 한다"}`,
    "replyOptions는 정중한 버전, 자연스러운 버전, 단호한 버전 순서로 작성해 주세요."
  ].join("\n");
}

/**
 * @param {unknown} payload
 * @returns {ReturnType<typeof normalizeReplyResult>}
 */
export function extractStructuredResult(payload) {
  const output = Array.isArray(payload?.output) ? payload.output : [];

  for (const item of output) {
    const contents = Array.isArray(item?.content) ? item.content : [];

    for (const content of contents) {
      const candidate =
        typeof content?.json === "object" && content.json
          ? content.json
          : tryParseJson(content?.text);
      const normalized = normalizeReplyResult(candidate);

      if (normalized) {
        return normalized;
      }
    }
  }

  return normalizeReplyResult(payload?.output_parsed);
}

function tryParseJson(value) {
  if (typeof value !== "string") {
    return null;
  }

  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

function jsonResponse(payload, status) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8"
    }
  });
}

export default async function handler(request, responseStream) {
  const response = await handleGenerateReplyRequest(request);
  const payload = await response.text();

  if (
    responseStream &&
    typeof responseStream.status === "function" &&
    typeof responseStream.setHeader === "function"
  ) {
    responseStream.status(response.status);

    for (const [key, value] of response.headers.entries()) {
      responseStream.setHeader(key, value);
    }

    responseStream.send(payload);
    return;
  }

  return response;
}

async function readRequestBody(request) {
  if (typeof request.json === "function") {
    return request.json().catch(() => null);
  }

  if (typeof request.body === "string") {
    try {
      return JSON.parse(request.body);
    } catch {
      return null;
    }
  }

  if (request.body && typeof request.body === "object") {
    return request.body;
  }

  return null;
}
