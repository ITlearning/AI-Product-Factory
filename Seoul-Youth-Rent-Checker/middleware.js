/**
 * Vercel Edge Middleware — 청년월세 체커 (v1: passthrough)
 *
 * v1 정책:
 * - 결과 페이지(`/r/[uuid]`)에는 동적 OG 주입을 하지 않는다.
 *   결과는 본인-only이며, 공유 카드는 도구 자체의 정적 OG (index.html에 박힘) 만 사용.
 *   (DESIGN.md "도구 공유 only, 결과 공유 X" 원칙)
 * - 따라서 middleware는 호출되지 않는다 (matcher 빈 배열).
 *
 * 학습 적용: vercel-middleware-non-nextjs
 * - 비-Next.js 프로젝트는 Web API 표준 (Request/Response) 사용. NextResponse 쓰지 않음.
 * - undefined 반환 시 다음 핸들러로 패스스루.
 *
 * 미래 확장 여지:
 * - 약관 변경 시 강제 재동의 라우팅
 * - A/B 실험 쿠키 기반 분기
 * - 봇 차단 (인덱스만 허용)
 *
 * 빈 matcher라 v1 동작에 0 영향. 파일 위치를 잡아두는 의미만 있음.
 */

export const config = {
  matcher: [],
};

/**
 * @param {Request} _request
 * @returns {Response | undefined}
 */
export default function middleware(_request) {
  // 통과 — Vercel SPA rewrite + api 라우팅이 그대로 동작한다.
  return undefined;
}
