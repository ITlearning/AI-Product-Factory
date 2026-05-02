/**
 * /api/og — Open Graph 카드 (도구 공유 전용)
 *
 * 1200×630 PNG. @vercel/og (Satori) + Pretendard subset (woff).
 * Node.js Serverless (50MB 한도).
 *
 * Date-Soragodong에서 검증된 패턴 그대로:
 * - module-init readFileSync (warm cache)
 * - handler (request, response) Node 시그니처
 * - arrayBuffer → Buffer → response.end() 직접 작성
 *
 * P3 디자인 결정: 결과 카드 OG 절대 X. 도구 자체를 공유하는
 * "친구야 너도 한번 해봐" 톤의 단일 카드만.
 */

import { ImageResponse } from "@vercel/og";
import { readFileSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

// Module init — warm invocation 재사용
const regularFont = readFileSync(
  join(__dirname, "fonts", "Pretendard-Regular.subset.woff"),
);
const semiBoldFont = readFileSync(
  join(__dirname, "fonts", "Pretendard-SemiBold.subset.woff"),
);

const BRAND_URL = "seoul-youth-rent-checker.vercel.app";

export default async function handler(request, response) {
  try {
    const imageResponse = new ImageResponse(buildBrandLayout(), {
      width: 1200,
      height: 630,
      fonts: [
        { name: "Pretendard", data: regularFont, weight: 400 },
        { name: "Pretendard", data: semiBoldFont, weight: 600 },
      ],
    });

    const buf = await imageResponse.arrayBuffer();
    response.setHeader("Content-Type", "image/png");
    response.setHeader(
      "Cache-Control",
      "public, s-maxage=604800, max-age=86400, stale-while-revalidate=3600",
    );
    response.end(Buffer.from(buf));
  } catch (err) {
    console.error("OG generation failed:", err);
    response.status(500).end("OG image generation failed");
  }
}

/**
 * 도구 공유 OG 카드 — Landing 메인 카피 그대로
 */
function buildBrandLayout() {
  return {
    type: "div",
    props: {
      style: {
        width: "100%",
        height: "100%",
        display: "flex",
        flexDirection: "column",
        justifyContent: "space-between",
        background: "#faf9f7",
        fontFamily: "Pretendard, sans-serif",
        padding: "80px",
      },
      children: [
        // 상단: 트러스트 배지
        {
          type: "div",
          props: {
            style: {
              display: "flex",
              alignItems: "center",
              gap: "12px",
              fontSize: "24px",
              color: "#525252",
              fontWeight: 400,
            },
            children: [
              {
                type: "div",
                props: {
                  style: {
                    width: "12px",
                    height: "12px",
                    background: "#ef4444",
                    borderRadius: "999px",
                  },
                },
              },
              "2026 서울시 공고 기반",
            ],
          },
        },
        // 가운데: 헤드라인 + 서브카피 (Landing 메인 그대로)
        {
          type: "div",
          props: {
            style: {
              display: "flex",
              flexDirection: "column",
              gap: "32px",
            },
            children: [
              // 헤드라인: 청년월세 240만원, 너 받을 수 있어?
              {
                type: "div",
                props: {
                  style: {
                    display: "flex",
                    flexDirection: "column",
                    fontSize: "92px",
                    fontWeight: 600,
                    lineHeight: 1.15,
                    letterSpacing: "-2.5px",
                    color: "#1a1a1a",
                  },
                  children: [
                    {
                      type: "div",
                      props: {
                        style: { display: "flex" },
                        children: [
                          "청년월세 ",
                          {
                            type: "span",
                            props: {
                              style: { color: "#ef4444" },
                              children: "240만원",
                            },
                          },
                          ",",
                        ],
                      },
                    },
                    {
                      type: "div",
                      props: {
                        style: { display: "flex" },
                        children: "너 받을 수 있어?",
                      },
                    },
                  ],
                },
              },
              // 서브카피: 5분 자가진단. 공인인증서 필요 없어요.
              //          익명 처리, 결과는 본인만 확인 가능.
              {
                type: "div",
                props: {
                  style: {
                    display: "flex",
                    flexDirection: "column",
                    fontSize: "30px",
                    color: "#525252",
                    fontWeight: 400,
                    lineHeight: 1.5,
                    gap: "4px",
                  },
                  children: [
                    {
                      type: "div",
                      props: {
                        style: { display: "flex" },
                        children: "5분 자가진단. 공인인증서 필요 없어요.",
                      },
                    },
                    {
                      type: "div",
                      props: {
                        style: { display: "flex" },
                        children: "익명 처리, 결과는 본인만 확인 가능.",
                      },
                    },
                  ],
                },
              },
            ],
          },
        },
        // 하단: 도메인
        {
          type: "div",
          props: {
            style: {
              display: "flex",
              justifyContent: "flex-end",
              alignItems: "center",
              fontSize: "22px",
              color: "#71717a",
              fontWeight: 400,
            },
            children: BRAND_URL,
          },
        },
      ],
    },
  };
}
