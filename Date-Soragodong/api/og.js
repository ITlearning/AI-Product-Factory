/**
 * /api/og — Vercel Edge Runtime OG image generator
 *
 * Generates a 1200×630 PNG for social sharing previews.
 * Uses @vercel/og (Satori) with bundled Pretendard subset.
 *
 * Query params: place, food, transport, budget
 */

import { ImageResponse } from "@vercel/og";

export const config = { runtime: "edge" };

// Module-level font cache — loaded once per isolate, reused across requests.
// Satori has no access to system fonts; fonts must be bundled.
let fontPromise = null;

async function getFonts() {
  if (fontPromise) return fontPromise;
  fontPromise = (async () => {
    const [regular, semiBold] = await Promise.all([
      fetch(new URL("./fonts/Pretendard-Regular.subset.woff", import.meta.url)),
      fetch(new URL("./fonts/Pretendard-SemiBold.subset.woff", import.meta.url)),
    ]);
    if (!regular.ok) throw new Error(`Font load failed: Pretendard-Regular ${regular.status}`);
    if (!semiBold.ok) throw new Error(`Font load failed: Pretendard-SemiBold ${semiBold.status}`);
    return [await regular.arrayBuffer(), await semiBold.arrayBuffer()];
  })();
  return fontPromise;
}

export default async function handler(request) {
  const { searchParams } = new URL(request.url);
  const place = searchParams.get("place") || "???";
  const food = searchParams.get("food") || "???";
  const transport = searchParams.get("transport") || "???";
  const budget = searchParams.get("budget") || "???";

  try {
    const [regularData, semiBoldData] = await getFonts();

    return new ImageResponse(
      {
        type: "div",
        props: {
          style: {
            width: "100%",
            height: "100%",
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            background: "linear-gradient(180deg, #0f0d2e 0%, #1a1060 35%, #6b3fa0 72%, #c97fd8 100%)",
            fontFamily: "Pretendard, sans-serif",
            padding: "48px",
            gap: "24px",
          },
          children: [
            // Title
            {
              type: "div",
              props: {
                style: {
                  fontSize: "40px",
                  fontWeight: 600,
                  color: "#ffffff",
                  letterSpacing: "-1px",
                  textAlign: "center",
                  textShadow: "0 2px 16px rgba(0,0,0,0.4)",
                },
                children: "🐚 소라고동님의 선택",
              },
            },
            // 2x2 result grid
            {
              type: "div",
              props: {
                style: {
                  display: "flex",
                  flexWrap: "wrap",
                  gap: "16px",
                  width: "100%",
                  justifyContent: "center",
                },
                children: [
                  ogCard("🗺️", "갈 곳", place),
                  ogCard("🍱", "먹을 곳", food),
                  ogCard("🚌", "탈 것", transport),
                  ogCard("💰", "금액", budget),
                ],
              },
            },
            // Footer
            {
              type: "div",
              props: {
                style: {
                  fontSize: "18px",
                  color: "rgba(255,255,255,0.5)",
                  marginTop: "8px",
                  fontWeight: 400,
                },
                children: "데이트 소라고동 — 오늘의 데이트를 소라고동님께",
              },
            },
          ],
        },
      },
      {
        width: 1200,
        height: 630,
        fonts: [
          { name: "Pretendard", data: regularData, weight: 400 },
          { name: "Pretendard", data: semiBoldData, weight: 600 },
        ],
      }
    );
  } catch (err) {
    // OG failure degrades gracefully — result page still works without OG image
    console.error("OG generation failed:", err);
    return new Response("OG image generation failed", { status: 500 });
  }
}

/**
 * @param {string} icon
 * @param {string} category
 * @param {string} value
 */
function ogCard(icon, category, value) {
  return {
    type: "div",
    props: {
      style: {
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: "8px",
        background: "rgba(255,255,255,0.1)",
        border: "1px solid rgba(255,255,255,0.2)",
        borderRadius: "20px",
        padding: "20px 28px",
        minWidth: "240px",
        flex: "1",
      },
      children: [
        { type: "span", props: { style: { fontSize: "32px" }, children: icon } },
        { type: "span", props: { style: { fontSize: "13px", color: "rgba(255,255,255,0.5)", fontWeight: 400 }, children: category } },
        { type: "span", props: { style: { fontSize: "22px", color: "#ffffff", fontWeight: 600 }, children: value } },
      ],
    },
  };
}
