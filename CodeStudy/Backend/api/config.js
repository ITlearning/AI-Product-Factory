/**
 * GET /api/config — Remote config for the iOS client.
 *
 * Allows runtime changes to:
 * - 인앱 설문 URL (Stage 1 demand discovery)
 * - 설문 활성화 토글 (응답 충분히 모이면 OFF)
 * - 언어별 설문 분기 (한글/영문 form 따로)
 *
 * Edit these via Vercel env vars. Redeploy applies in ~30s.
 *
 * Response is edge-cached for 5 min with stale-while-revalidate
 * — so even cold starts are fast and a Vercel/Neon outage doesn't
 * starve the iOS client (cached value still served).
 *
 * Env vars:
 *   SURVEY_ENABLED  — "true" / "false" (default true)
 *   SURVEY_URL      — Korean form URL (required when enabled)
 *   SURVEY_URL_EN   — English form URL (optional, falls back to SURVEY_URL)
 */
export async function GET() {
  const surveyEnabledRaw = (process.env.SURVEY_ENABLED ?? 'true').toLowerCase();
  const surveyEnabledFlag = surveyEnabledRaw !== 'false' && surveyEnabledRaw !== '0';
  const surveyURL = process.env.SURVEY_URL ?? '';
  const surveyURLEn = process.env.SURVEY_URL_EN ?? '';

  // 활성화 = 토글 ON + 최소 한 개 이상 form URL 존재.
  // 영문만 있고 한글 없는 케이스도 enable (영어권 우선 출시 시나리오).
  const surveyEnabled = surveyEnabledFlag && (surveyURL.length > 0 || surveyURLEn.length > 0);

  const body = {
    schemaVersion: 2,
    surveyEnabled,
    surveyURL,
    surveyURLEn,
  };

  return new Response(JSON.stringify(body), {
    status: 200,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=600',
    },
  });
}
