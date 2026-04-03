/**
 * Vercel Edge Middleware — OG meta tag injection for /result routes
 *
 * Problem: Vite SPA returns static index.html to all routes (including crawlers).
 * That static HTML has generic OG tags, so KakaoTalk / iMessage / Twitter previews
 * show the default image instead of the specific course result.
 *
 * Solution: Intercept GET /result?... requests at the Edge, fetch the static HTML,
 * inject dynamic OG meta tags, return the modified HTML.
 * The SPA JS still hydrates normally — this only affects the initial HTML response.
 *
 * Note: Non-Next.js Vercel middleware uses standard Web APIs (Request/Response).
 * Returning undefined passes through to the next handler.
 */

export const config = {
  matcher: ["/result"],
};

export default async function middleware(request) {
  const url = new URL(request.url);

  // Only apply to GET requests for /result with course params
  if (request.method !== "GET") return;

  const place = url.searchParams.get("place");
  const food = url.searchParams.get("food");
  const transport = url.searchParams.get("transport");
  const budget = url.searchParams.get("budget");

  // If any required param is missing, pass through as-is
  if (!place || !food || !transport || !budget) return;

  // Fetch the static index.html
  const indexUrl = new URL("/", request.url);
  let html;
  try {
    const res = await fetch(indexUrl);
    if (!res.ok) return;
    html = await res.text();
  } catch {
    return;
  }

  // Build OG image URL
  const ogParams = new URLSearchParams({ place, food, transport, budget });
  const ogImageUrl = `${url.origin}/api/og?${ogParams.toString()}`;
  const ogTitle = `🐚 ${place} · ${food} · ${transport} · ${budget}`;
  const ogDescription = "소라고동님이 오늘 우리 데이트 코스를 뽑아주셨어요!";

  // Inject dynamic OG tags — replace the generic ones in index.html
  const injected = html
    .replace(
      /<meta property="og:title"[^>]*>/,
      `<meta property="og:title" content="${escapeHtml(ogTitle)}" />`
    )
    .replace(
      /<meta property="og:description"[^>]*>/,
      `<meta property="og:description" content="${escapeHtml(ogDescription)}" />`
    )
    .replace(
      /<meta property="og:image"[^>]*>/,
      `<meta property="og:image" content="${escapeHtml(ogImageUrl)}" />`
    )
    .replace(
      /<meta name="twitter:card"[^>]*>/,
      `<meta name="twitter:card" content="summary_large_image" />`
    );

  return new Response(injected, {
    headers: {
      "content-type": "text/html; charset=utf-8",
      // Cache at CDN keyed by full URL (each course combo is unique), but not in browser
      "cache-control": "public, s-maxage=86400, max-age=0, stale-while-revalidate=3600",
    },
  });
}

/** @param {string} str */
function escapeHtml(str) {
  return str
    .replace(/&/g, "&amp;")
    .replace(/"/g, "&quot;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}
