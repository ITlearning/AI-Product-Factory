/**
 * /api/og — Vercel Edge Runtime OG image generator
 *
 * Generates a 1200×630 PNG for social sharing previews.
 * Uses @vercel/og (Satori) with bundled NotoSansKR subset.
 *
 * Query params: place, food, transport, budget
 */

import { ImageResponse } from "@vercel/og";

export const config = { runtime: "edge" };

// Module-level font cache — loaded once, reused across invocations.
// Satori has no access to system fonts or Google Fonts; font must be bundled.
let fontCache = null;

async function getFont() {
  if (fontCache) return fontCache;
  const url = new URL("./fonts/NotoSansKR-subset.ttf", import.meta.url);
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Font load failed: ${res.status}`);
  fontCache = await res.arrayBuffer();
  return fontCache;
}

export default async function handler(request) {
  const { searchParams } = new URL(request.url);
  const place = searchParams.get("place") || "???";
  const food = searchParams.get("food") || "???";
  const transport = searchParams.get("transport") || "???";
  const budget = searchParams.get("budget") || "???";

  try {
    const fontData = await getFont();

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
            fontFamily: "Noto Sans KR, sans-serif",
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
                  fontWeight: 900,
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
        fonts: [{ name: "Noto Sans KR", data: fontData, weight: 700 }],
      }
    );
  } catch (err) {
    // OG failure degrades gracefully — static default image used by middleware
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
        { type: "span", props: { style: { fontSize: "13px", color: "rgba(255,255,255,0.5)", fontWeight: 500 }, children: category } },
        { type: "span", props: { style: { fontSize: "22px", color: "#ffffff", fontWeight: 700 }, children: value } },
      ],
    },
  };
}
