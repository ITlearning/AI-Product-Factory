import test from "node:test";
import assert from "node:assert/strict";

import {
  buildReplyResult,
  normalizeAiReplyDraft,
  normalizeReplyResult
} from "../../src/domain/schema.js";

test("normalizes a valid AI draft payload", () => {
  const result = normalizeAiReplyDraft({
    replyOptions: [
      { text: "오늘은 좀 어려울 것 같아.", toneLabel: "부드럽게", whyItWorks: "부담을 낮춘다." },
      { text: "이번엔 어려워. 고마운데 패스할게.", toneLabel: "예의 있게 확실하게", whyItWorks: "균형이 좋다." },
      { text: "이번엔 어려워.", toneLabel: "짧게 끝내기", whyItWorks: "짧게 끝낸다." }
    ],
    avoidPhrase: "나중에 보자"
  });

  assert.deepEqual(result, {
    replyOptions: [
      { text: "오늘은 좀 어려울 것 같아.", toneLabel: "부드럽게", whyItWorks: "부담을 낮춘다." },
      { text: "이번엔 어려워. 고마운데 패스할게.", toneLabel: "예의 있게 확실하게", whyItWorks: "균형이 좋다." },
      { text: "이번엔 어려워.", toneLabel: "짧게 끝내기", whyItWorks: "짧게 끝낸다." }
    ],
    avoidPhrase: "나중에 보자"
  });
});

test("rejects duplicate reply texts", () => {
  const result = normalizeAiReplyDraft({
    replyOptions: [
      { text: "안 될 것 같아.", toneLabel: "부드럽게", whyItWorks: "짧다" },
      { text: "안 될 것 같아.", toneLabel: "예의 있게 확실하게", whyItWorks: "자연스럽다" },
      { text: "이번엔 어렵겠어.", toneLabel: "짧게 끝내기", whyItWorks: "분명하다" }
    ],
    avoidPhrase: "다음에 보자"
  });

  assert.equal(result, null);
});

test("builds a full reply result with coaching metadata", () => {
  const result = buildReplyResult(
    {
      replyOptions: [
        { text: "오늘은 좀 어려울 것 같아.", toneLabel: "부드럽게", whyItWorks: "부담을 낮춘다." },
        { text: "이번엔 어려워. 고마운데 패스할게.", toneLabel: "예의 있게 확실하게", whyItWorks: "균형이 좋다." },
        { text: "이번엔 어려워.", toneLabel: "짧게 끝내기", whyItWorks: "짧게 끝낸다." }
      ],
      avoidPhrase: "나중에 보자"
    },
    {
      recommendedTone: "polite-firm",
      coachNote: "예의는 유지하되 결론을 먼저 두면 차갑기보다 분명하게 읽혀요."
    }
  );

  assert.deepEqual(result, {
    replyOptions: [
      { text: "오늘은 좀 어려울 것 같아.", toneLabel: "부드럽게", whyItWorks: "부담을 낮춘다." },
      { text: "이번엔 어려워. 고마운데 패스할게.", toneLabel: "예의 있게 확실하게", whyItWorks: "균형이 좋다." },
      { text: "이번엔 어려워.", toneLabel: "짧게 끝내기", whyItWorks: "짧게 끝낸다." }
    ],
    recommendedTone: "polite-firm",
    coachNote: "예의는 유지하되 결론을 먼저 두면 차갑기보다 분명하게 읽혀요.",
    avoidPhrase: "나중에 보자"
  });
});

test("normalizes a valid full reply result payload", () => {
  const result = normalizeReplyResult({
    replyOptions: [
      { text: "오늘은 좀 어려울 것 같아.", toneLabel: "부드럽게", whyItWorks: "부담을 낮춘다." },
      { text: "이번엔 어려워. 고마운데 패스할게.", toneLabel: "예의 있게 확실하게", whyItWorks: "균형이 좋다." },
      { text: "이번엔 어려워.", toneLabel: "짧게 끝내기", whyItWorks: "짧게 끝낸다." }
    ],
    recommendedTone: "polite-firm",
    coachNote: "예의는 유지하되 결론을 먼저 두면 차갑기보다 분명하게 읽혀요.",
    avoidPhrase: "나중에 보자"
  });

  assert.equal(result?.recommendedTone, "polite-firm");
  assert.equal(result?.avoidPhrase, "나중에 보자");
});
