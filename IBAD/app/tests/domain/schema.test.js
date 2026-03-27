import test from "node:test";
import assert from "node:assert/strict";

import { normalizeReplyResult } from "../../src/domain/schema.js";

test("normalizes a valid reply payload", () => {
  const result = normalizeReplyResult({
    replyOptions: [
      { text: "오늘은 좀 어려울 것 같아.", toneLabel: "부드럽게", whyItWorks: "부담을 낮춘다." },
      { text: "이번엔 어려워. 고마운데 패스할게.", toneLabel: "예의 있게 확실하게", whyItWorks: "균형이 좋다." },
      { text: "이번엔 어려워.", toneLabel: "짧게 끝내기", whyItWorks: "짧게 끝낸다." }
    ]
  });

  assert.deepEqual(result, {
    replyOptions: [
      { text: "오늘은 좀 어려울 것 같아.", toneLabel: "부드럽게", whyItWorks: "부담을 낮춘다." },
      { text: "이번엔 어려워. 고마운데 패스할게.", toneLabel: "예의 있게 확실하게", whyItWorks: "균형이 좋다." },
      { text: "이번엔 어려워.", toneLabel: "짧게 끝내기", whyItWorks: "짧게 끝낸다." }
    ]
  });
});

test("rejects duplicate reply texts", () => {
  const result = normalizeReplyResult({
    replyOptions: [
      { text: "안 될 것 같아.", toneLabel: "부드럽게", whyItWorks: "짧다" },
      { text: "안 될 것 같아.", toneLabel: "예의 있게 확실하게", whyItWorks: "자연스럽다" },
      { text: "이번엔 어렵겠어.", toneLabel: "짧게 끝내기", whyItWorks: "분명하다" }
    ]
  });

  assert.equal(result, null);
});
