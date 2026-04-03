/**
 * /api/og — OG image generator (Node.js Serverless Function)
 *
 * Generates a 1200×630 PNG for social sharing previews.
 * Uses @vercel/og (Satori) with bundled Pretendard subset.
 * Runs as Node.js serverless (50 MB limit) — edge was 1 MB which is too small for fonts.
 *
 * Query params: place, food, transport, budget
 */

import { ImageResponse } from "@vercel/og";
import { readFileSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

// Load fonts at module init — shared across warm invocations
const regularFont = readFileSync(join(__dirname, "fonts", "Pretendard-Regular.subset.woff"));
const semiBoldFont = readFileSync(join(__dirname, "fonts", "Pretendard-SemiBold.subset.woff"));

export default async function handler(request, response) {
  const { searchParams } = new URL(request.url, "http://localhost");
  const normalize = (v, fallback = "???") => {
    if (!v) return fallback;
    return v.trim().slice(0, 80);
  };
  const place = normalize(searchParams.get("place"));
  const food = normalize(searchParams.get("food"));
  const transport = normalize(searchParams.get("transport"));
  const budget = normalize(searchParams.get("budget"));

  try {
    const imageResponse = new ImageResponse(
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
          { name: "Pretendard", data: regularFont, weight: 400 },
          { name: "Pretendard", data: semiBoldFont, weight: 600 },
        ],
      }
    );

    // Convert ImageResponse to Node.js response
    const buf = await imageResponse.arrayBuffer();
    response.setHeader("Content-Type", "image/png");
    response.setHeader("Cache-Control", "public, s-maxage=86400, max-age=0");
    response.end(Buffer.from(buf));
  } catch (err) {
    // OG failure degrades gracefully — result page still works without OG image
    console.error("OG generation failed:", err);
    response.status(500).end("OG image generation failed");
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
