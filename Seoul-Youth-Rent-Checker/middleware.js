/**
 * Vercel Middleware — OG meta tag absolute URL injection for "/"
 *
 * Problem: index.html ships with `<meta property="og:image" content="/api/og">` —
 * a relative path. KakaoTalk / Slack / Twitter / iMessage OG fetchers do NOT
 * resolve relative URLs, so the preview image never appears in shared links.
 *
 * Solution: Intercept GET / requests at the platform level, fetch the static
 * index.html, rewrite og:image (and add og:url) to absolute URLs based on the
 * current request origin. Works on production AND preview deployments — no
 * hardcoded domain.
 *
 * Notes:
 * - matcher is restricted to "/" so /api/* and static assets (/assets/*, /vite.svg)
 *   pass through untouched. /index.html fetched below also does NOT re-trigger
 *   middleware (matcher is exact "/").
 * - Vercel non-Next middleware uses standard Web APIs (Request/Response).
 * - Returning undefined falls through to the default static handler.
 */

export const config = {
  matcher: ["/"],
};

export default async function middleware(request) {
  if (request.method !== "GET") return;

  const url = new URL(request.url);
  const origin = url.origin;

  // Fetch the static index.html. Because matcher is exact "/", a fetch to
  // "/index.html" hits the static handler directly and does NOT loop.
  let html;
  try {
    const res = await fetch(new URL("/index.html", request.url));
    if (!res.ok) return;
    html = await res.text();
  } catch {
    return;
  }

  const ogImageUrl = `${origin}/api/og`;
  const ogUrl = `${origin}/`;

  // Replace og:image relative URL with absolute. Tolerate `content="/api/og"`
  // with or without trailing slash and self-closing slash.
  let injected = html.replace(
    /<meta\s+property="og:image"\s+content="[^"]*"\s*\/?>/,
    `<meta property="og:image" content="${ogImageUrl}" />`,
  );

  // Add og:url right after og:type if missing (KakaoTalk uses og:url to
  // canonicalize the share target).
  if (!/<meta\s+property="og:url"/.test(injected)) {
    injected = injected.replace(
      /(<meta\s+property="og:type"\s+content="[^"]*"\s*\/?>)/,
      `$1\n    <meta property="og:url" content="${ogUrl}" />`,
    );
  }

  return new Response(injected, {
    status: 200,
    headers: {
      "content-type": "text/html; charset=utf-8",
      // CDN cache 1d, browser 0 (so Tabber can ship updates without breaking shares).
      "cache-control":
        "public, s-maxage=86400, max-age=0, stale-while-revalidate=3600",
    },
  });
}
