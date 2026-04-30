import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

/**
 * Vite plugin: og:image / og:url 절대 URL 주입.
 *
 * 카톡 / 슬랙 / iMessage / Twitter 의 OG fetcher 는 상대 경로 (`/api/og`) 를
 * resolve 하지 않는다 → 미리보기 카드가 안 뜬다. 빌드 타임에 dist/index.html 에
 * 절대 URL 을 박는다.
 *
 * URL 우선순위:
 *  1. VITE_PUBLIC_URL  — 명시적 production 도메인 (커스텀 도메인 박을 때 사용)
 *  2. VERCEL_URL       — Vercel 이 자동 주입. preview/production 각자의 호스트.
 *  3. fallback          — seoul-youth-rent-checker.vercel.app (production preview)
 *
 * 이전엔 middleware.js 가 런타임에 같은 일을 했으나, 빌드 타임 주입이
 * (a) cache 친화 (b) middleware 호출/매처 디버깅 X (c) OG fetcher 100% 호환.
 */
function ogMetaAbsoluteUrl() {
  return {
    name: "og-meta-absolute-url",
    transformIndexHtml(html) {
      const explicit = process.env.VITE_PUBLIC_URL;
      const vercelUrl = process.env.VERCEL_URL
        ? `https://${process.env.VERCEL_URL}`
        : null;
      const fallback = "https://seoul-youth-rent-checker.vercel.app";
      const url = explicit || vercelUrl || fallback;

      let out = html.replace(
        /<meta\s+property="og:image"\s+content="[^"]*"\s*\/?>/,
        `<meta property="og:image" content="${url}/api/og" />`,
      );

      // og:url 이 이미 있으면 건너뛰고, 없으면 og:type 뒤에 추가.
      if (!/<meta\s+property="og:url"/.test(out)) {
        out = out.replace(
          /(<meta\s+property="og:type"\s+content="[^"]*"\s*\/?>)/,
          `$1\n    <meta property="og:url" content="${url}/" />`,
        );
      }
      return out;
    },
  };
}

export default defineConfig({
  base: "./",
  plugins: [react(), ogMetaAbsoluteUrl()],
  build: {
    rollupOptions: {
      input: {
        main: "index.html",
      },
    },
  },
});
