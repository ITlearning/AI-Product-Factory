/**
 * POST /api/send-test-email?token=<TEST_EMAIL_TOKEN>
 *
 * 임시 1회 발송 테스트 엔드포인트. yo7504@kakao.com으로 D-day 알림 미리보기를 발송한다.
 *
 * 보안:
 * - query param `token`이 환경변수 TEST_EMAIL_TOKEN과 일치해야 함 (단순 토큰 검증).
 * - POST만 허용.
 *
 * 사용:
 *   curl -X POST "https://<host>/api/send-test-email?token=<TEST_EMAIL_TOKEN>"
 *
 * 발송 인프라:
 * - Resend (Vercel Marketplace 1클릭 설치 → RESEND_API_KEY 자동 주입)
 * - 발신자: onboarding@resend.dev (도메인 검증 없이 사용 가능, 무료 plan 100/day)
 *
 * v1.5에서 cron 자동 발송으로 확장 예정.
 *
 * 패턴 참조:
 * - api/check.js: Pages-style `export default async function handler(req, res)` 시그니처 통일.
 *   App Router named exports로 hang 발생하던 학습(vercel-legacy-handler-hangs) 적용.
 */

import { Resend } from "resend";

export const config = { runtime: "nodejs" };

const TEST_RECIPIENT = "yo7504@kakao.com";
const FROM_ADDRESS = "청년월세 체커 <onboarding@resend.dev>";

function getQueryToken(req) {
  // req.url은 path+query만 들어오므로 가짜 base 붙여 파싱.
  try {
    const url = new URL(req.url, "http://localhost");
    return url.searchParams.get("token");
  } catch {
    return null;
  }
}

function buildHtml() {
  return `
    <div style="font-family: 'Pretendard', -apple-system, BlinkMacSystemFont, sans-serif; max-width: 480px; margin: 0 auto; padding: 32px; color: #1a1a1a;">
      <h1 style="font-size: 24px; font-weight: 800; margin-bottom: 16px;">
        청년월세 체커
      </h1>
      <p style="font-size: 15px; line-height: 1.6; color: #525252;">
        알림 메일 발송 테스트입니다.
      </p>
      <p style="font-size: 15px; line-height: 1.6; color: #525252; margin-top: 16px;">
        5/19 마감까지 D-day 알림이 이런 형식으로 발송될 예정이에요.
      </p>
      <p style="font-size: 13px; color: #71717a; margin-top: 32px;">
        v1.5에서 cron 자동 발송 추가 예정.
      </p>
    </div>
  `;
}

/**
 * @param {import("http").IncomingMessage & {body?: any}} req
 * @param {import("http").ServerResponse} res
 */
export default async function handler(req, res) {
  res.setHeader("content-type", "application/json; charset=utf-8");

  if (req.method !== "POST") {
    res.statusCode = 405;
    res.setHeader("allow", "POST");
    res.end(JSON.stringify({ message: "POST만 허용돼요." }));
    return;
  }

  const expected = process.env.TEST_EMAIL_TOKEN;
  if (!expected) {
    res.statusCode = 500;
    res.end(
      JSON.stringify({
        message: "TEST_EMAIL_TOKEN 환경변수가 설정되지 않았어요.",
      }),
    );
    return;
  }

  const token = getQueryToken(req);
  if (token !== expected) {
    res.statusCode = 403;
    res.end(JSON.stringify({ message: "Forbidden" }));
    return;
  }

  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) {
    res.statusCode = 500;
    res.end(
      JSON.stringify({
        message: "RESEND_API_KEY 환경변수가 없어요. Vercel Marketplace에서 Resend 통합을 추가해주세요.",
      }),
    );
    return;
  }

  try {
    const resend = new Resend(apiKey);
    const result = await resend.emails.send({
      from: FROM_ADDRESS,
      to: [TEST_RECIPIENT],
      subject: "[청년월세 체커] 임시 테스트 메일",
      html: buildHtml(),
    });

    if (result.error) {
      res.statusCode = 502;
      res.end(
        JSON.stringify({
          success: false,
          error: result.error,
        }),
      );
      return;
    }

    res.statusCode = 200;
    res.end(
      JSON.stringify({
        success: true,
        messageId: result.data?.id ?? null,
        to: TEST_RECIPIENT,
      }),
    );
  } catch (err) {
    res.statusCode = 500;
    res.end(
      JSON.stringify({
        success: false,
        message: err?.message || "메일 발송 중 알 수 없는 오류",
      }),
    );
  }
}
