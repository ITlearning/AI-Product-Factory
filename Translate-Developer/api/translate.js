import { DEFAULT_OPENAI_MODEL, OPENAI_RESPONSES_URL } from "../src/config.js";
import { buildSystemPrompt, buildUserPrompt } from "../src/ai/prompt.js";
import { normalizeAudience } from "../src/data/audiences.js";
import {
  normalizeTranslationResult,
  TRANSLATION_JSON_SCHEMA
} from "../src/engine/schema.js";
import { normalizeInput } from "../src/utils/text.js";

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
  const audience = normalizeAudience(body?.audience);
  const categoryId = typeof body?.categoryId === "string" ? body.categoryId : "developer";

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
            content: [{ type: "input_text", text: buildSystemPrompt(audience, categoryId) }]
          },
          {
            role: "user",
            content: [
              {
                type: "input_text",
                text: buildUserPrompt(input, categoryId)
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
      const upstreamStatus = upstreamResponse.status;
      const upstreamError = await readUpstreamError(upstreamResponse);

      return jsonResponse(
        {
          error: upstreamError,
          upstreamStatus
        },
        mapUpstreamStatus(upstreamStatus)
      );
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
        typeof content?.parsed === "object" && content.parsed
          ? content.parsed
          : typeof content?.json === "object" && content.json
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

/**
 * @param {Response} response
 * @returns {Promise<string>}
 */
async function readUpstreamError(response) {
  const contentType = response.headers.get("content-type") ?? "";

  if (contentType.includes("application/json")) {
    const payload = await response.json().catch(() => null);
    const message = normalizeUpstreamErrorMessage(payload);

    if (message) {
      return message;
    }
  } else {
    const text = await response.text().catch(() => "");
    const normalizedText = normalizeErrorText(text);

    if (normalizedText) {
      return normalizedText;
    }
  }

  if (response.status === 401 || response.status === 403) {
    return "OpenAI authentication failed.";
  }

  if (response.status === 429) {
    return "OpenAI rate limit exceeded.";
  }

  return "AI upstream request failed.";
}

/**
 * @param {number} status
 * @returns {number}
 */
function mapUpstreamStatus(status) {
  if (status === 401 || status === 403 || status === 429) {
    return status;
  }

  return 502;
}

/**
 * @param {unknown} payload
 * @returns {string | null}
 */
function normalizeUpstreamErrorMessage(payload) {
  if (!payload || typeof payload !== "object") {
    return null;
  }

  const directMessage = normalizeErrorText(payload?.error);

  if (directMessage) {
    return directMessage;
  }

  if (payload.error && typeof payload.error === "object") {
    return normalizeErrorText(payload.error.message);
  }

  return null;
}

/**
 * @param {unknown} value
 * @returns {string | null}
 */
function normalizeErrorText(value) {
  if (typeof value !== "string") {
    return null;
  }

  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}
