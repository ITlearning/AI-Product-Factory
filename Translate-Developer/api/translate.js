import { DEFAULT_OPENAI_MODEL, OPENAI_RESPONSES_URL } from "../src/config.js";
import {
  normalizeTranslationResult,
  TRANSLATION_JSON_SCHEMA
} from "../src/engine/schema.js";
import { normalizeInput } from "../src/utils/text.js";

const SYSTEM_PROMPT = [
  "당신은 개발자 설명을 비전공자가 이해할 수 있는 한국어로 바꾸는 번역기다.",
  "사실을 추가로 지어내지 말고 입력에 있는 내용만 바탕으로 설명한다.",
  "기술 용어는 무조건 지우지 말고, 꼭 필요한 경우 쉬운 말로 풀어쓴다.",
  "summary, easyExplanation, importantNow, actionForReader는 각각 역할이 겹치지 않게 작성한다.",
  "termPairs에는 원문 기술 표현과 쉬운 표현만 넣는다.",
  "응답은 반드시 주어진 JSON 스키마만 따른다."
].join(" ");

/**
 * @param {Request | { method?: string, json?: () => Promise<unknown>, body?: unknown }} request
 * @param {{ fetchImpl?: typeof fetch, apiKey?: string, model?: string }} [options]
 * @returns {Promise<Response>}
 */
export async function handleTranslateRequest(request, options = {}) {
  if ((request.method ?? "POST").toUpperCase() !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const body = await readRequestBody(request);
  const input = normalizeInput(typeof body?.input === "string" ? body.input : "");

  if (!input) {
    return jsonResponse({ error: "입력 메시지가 필요합니다." }, 400);
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
            content: [
              {
                type: "input_text",
                text: `다음 개발자 메시지를 번역해 주세요.\n\n${input}`
              }
            ]
          }
        ],
        text: {
          format: {
            type: "json_schema",
            name: TRANSLATION_JSON_SCHEMA.name,
            schema: TRANSLATION_JSON_SCHEMA.schema,
            strict: true
          }
        }
      })
    });

    if (!upstreamResponse.ok) {
      return jsonResponse({ error: "AI upstream request failed." }, 502);
    }

    const upstreamPayload = await upstreamResponse.json();
    const result = extractStructuredResult(upstreamPayload);

    if (!result) {
      return jsonResponse({ error: "AI returned an invalid result." }, 502);
    }

    return jsonResponse({ result, source: "ai" }, 200);
  } catch {
    return jsonResponse({ error: "AI request failed." }, 502);
  }
}

/**
 * @param {unknown} payload
 * @returns {import("../src/engine/types.js").TranslationResult | null}
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
      const normalized = normalizeTranslationResult(candidate);

      if (normalized) {
        return normalized;
      }
    }
  }

  const directNormalized = normalizeTranslationResult(payload?.output_parsed);
  return directNormalized;
}

/**
 * @param {unknown} value
 * @returns {unknown}
 */
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

/**
 * @param {unknown} payload
 * @param {number} status
 * @returns {Response}
 */
function jsonResponse(payload, status) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8"
    }
  });
}

export default async function handler(request, responseStream) {
  const response = await handleTranslateRequest(request);
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

/**
 * @param {Request | { json?: () => Promise<unknown>, body?: unknown }} request
 * @returns {Promise<unknown>}
 */
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
