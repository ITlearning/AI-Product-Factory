/**
 * /api/og — Open Graph 카드 (도구 공유 전용)
 *
 * 1200×630 PNG. @vercel/og (Satori) + Pretendard 서브셋.
 * Node Serverless로 실행 (Edge 1MB 한도 회피 — vercel-edge-font-size-limit 학습).
 *
 * P3 디자인 결정: 결과 카드 OG 절대 X. 사용자 결과(자격 OK/NO,
 * 보증금, 소득)는 OG로 노출하지 않는다. 도구 자체를 공유하는
 * "5분 안에 청년월세지원 자격 확인" 톤의 단일 카드만.
 */

import { ImageResponse } from "@vercel/og";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const config = { runtime: "nodejs" };

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Module init: 폰트는 한 번만 읽어서 warm invocation에서 재사용
// (og-font-readfilesync 학습 — 매 요청마다 readFileSync 호출하면 cold 외에도 비용 발생).
const FONT_REGULAR = fs.readFileSync(
  path.join(__dirname, "fonts", "Pretendard-Regular.subset.woff2"),
);
const FONT_BOLD = fs.readFileSync(
  path.join(__dirname, "fonts", "Pretendard-Bold.subset.woff2"),
);

// 도메인 미정 — Tabber가 vercel.app 또는 커스텀 도메인 결정 후 교체 필요.
const BRAND_URL = "wolse.kr";

export default async function handler() {
  return new ImageResponse(
    {
      type: "div",
      props: {
        style: {
          width: "1200px",
          height: "630px",
          background: "#faf9f7",
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
          padding: "80px",
          fontFamily: "Pretendard",
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
          // 가운데: 헤드라인 + 서브카피
          {
            type: "div",
            props: {
              style: {
                display: "flex",
                flexDirection: "column",
                gap: "24px",
              },
              children: [
                {
                  type: "div",
                  props: {
                    style: {
                      display: "flex",
                      flexWrap: "wrap",
                      fontSize: "92px",
                      fontWeight: 800,
                      lineHeight: 1.15,
                      letterSpacing: "-0.02em",
                      color: "#1a1a1a",
                    },
                    children: [
                      "청년월세 ",
                      {
                        type: "span",
                        props: {
                          style: { color: "#ef4444" },
                          children: "240만원",
                        },
                      },
                      ", 너 받을 수 있어?",
                    ],
                  },
                },
                {
                  type: "div",
                  props: {
                    style: {
                      fontSize: "32px",
                      color: "#525252",
                      fontWeight: 400,
                    },
                    children: "5분 자가진단. 공인인증서 필요 없어요.",
                  },
                },
              ],
            },
          },
          // 하단: 마감 + 도메인
          {
            type: "div",
            props: {
              style: {
                display: "flex",
                justifyContent: "space-between",
                alignItems: "center",
                fontSize: "22px",
                color: "#71717a",
                fontWeight: 400,
              },
              children: [
                "신청 마감 5/19 18:00",
                BRAND_URL,
              ],
            },
          },
        ],
      },
    },
    {
      width: 1200,
      height: 630,
      fonts: [
        {
          name: "Pretendard",
          data: FONT_REGULAR,
          style: "normal",
          weight: 400,
        },
        {
          name: "Pretendard",
          data: FONT_BOLD,
          style: "normal",
          weight: 800,
        },
      ],
      headers: {
        "cache-control":
          "public, max-age=86400, s-maxage=604800, stale-while-revalidate=3600",
      },
    },
  );
}
