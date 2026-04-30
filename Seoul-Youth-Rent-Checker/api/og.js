/**
 * /api/og — Open Graph 카드 (도구 공유 전용)
 *
 * 1200×630 PNG. @vercel/og (Satori) + Pretendard 서브셋.
 * Node Serverless로 실행 (Edge 1MB 한도 회피 — vercel-edge-font-size-limit 학습).
 *
 * P3 디자인 결정: 결과 카드 OG 절대 X. 사용자 결과(자격 OK/NO,
 * 보증금, 소득)는 OG로 노출하지 않는다. 도구 자체를 공유하는
 * "5분 안에 청년월세지원 자격 확인" 톤의 단일 카드만.
 *
 * 톤: "내 결과 자랑"이 아니라 "친구야 너도 해봐" 모멘트.
 * 결과를 공유하는 게 아니라 도구를 추천하는 카드.
 */

import { ImageResponse } from "@vercel/og";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const config = { runtime: "nodejs" };

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// 폰트는 warm invocation에서 재사용되도록 모듈 스코프에 캐시.
// (og-font-readfilesync 학습 — 매 요청마다 readFileSync 호출하면 cold 외에도 비용 발생.)
//
// 단, module-init 시점의 readFileSync 가 production에서 throw 하면 함수 자체가
// 매 invocation timeout 으로 죽는다 (관측됨: 504 FUNCTION_INVOCATION_TIMEOUT).
// Vercel 은 api/ 디렉토리의 비-JS 파일을 자동 번들 안 하므로
// vercel.json `functions["api/og.js"].includeFiles` 로 fonts/** 를 강제 포함시킨다.
// 그래도 path resolution 실패 안전망으로 try/catch + 1회만 시도 (warm cache).
let FONT_REGULAR = null;
let FONT_BOLD = null;
let FONTS_LOADED = false;
function loadFontsOnce() {
  if (FONTS_LOADED) return;
  FONTS_LOADED = true;
  try {
    FONT_REGULAR = fs.readFileSync(
      path.join(__dirname, "fonts", "Pretendard-Regular.subset.woff2"),
    );
    FONT_BOLD = fs.readFileSync(
      path.join(__dirname, "fonts", "Pretendard-Bold.subset.woff2"),
    );
  } catch (err) {
    // 폰트 로드 실패해도 OG 카드 자체는 렌더 (Satori 기본 폰트로 fallback).
    // 한글 글리프는 □ 로 나오겠지만, 504 보다는 낫고 카톡 미리보기는 뜬다.
    console.error("[api/og] font load failed, falling back to default:", err);
    FONT_REGULAR = null;
    FONT_BOLD = null;
  }
}

// 도메인 미정 — Tabber가 vercel.app 또는 커스텀 도메인 결정 후 교체 필요.
const BRAND_URL = "wolse.kr";

export default async function handler() {
  loadFontsOnce();
  const fonts = [];
  if (FONT_REGULAR) {
    fonts.push({ name: "Pretendard", data: FONT_REGULAR, style: "normal", weight: 400 });
  }
  if (FONT_BOLD) {
    fonts.push({ name: "Pretendard", data: FONT_BOLD, style: "normal", weight: 800 });
  }
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
          // 가운데: 헤드라인 + 서브카피 ("친구야, 너도 한번 해봐" 톤)
          // 결과 자랑이 아니라 도구 추천 모멘트. "친구야"에 빨강 액센트.
          {
            type: "div",
            props: {
              style: {
                display: "flex",
                flexDirection: "column",
                gap: "32px",
              },
              children: [
                {
                  type: "div",
                  props: {
                    style: {
                      display: "flex",
                      flexDirection: "column",
                      fontSize: "104px",
                      fontWeight: 800,
                      lineHeight: 1.1,
                      letterSpacing: "-0.03em",
                      color: "#1a1a1a",
                    },
                    children: [
                      {
                        type: "div",
                        props: {
                          style: { display: "flex" },
                          children: [
                            {
                              type: "span",
                              props: {
                                style: { color: "#ef4444" },
                                children: "친구야",
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
                          children: "너도 한번 해봐.",
                        },
                      },
                    ],
                  },
                },
                {
                  type: "div",
                  props: {
                    style: {
                      display: "flex",
                      fontSize: "34px",
                      color: "#525252",
                      fontWeight: 400,
                      lineHeight: 1.4,
                    },
                    children: "청년월세 240만원 자격, 5분 안에 확인할 수 있어.",
                  },
                },
              ],
            },
          },
          // 하단: 트러스트 한 줄 + 도메인
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
                "공인인증서 X · 익명 자가진단",
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
      fonts,
      headers: {
        "cache-control":
          "public, max-age=86400, s-maxage=604800, stale-while-revalidate=3600",
      },
    },
  );
}
