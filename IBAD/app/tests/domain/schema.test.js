import test from "node:test";
import assert from "node:assert/strict";

import { normalizeReplyResult } from "../../src/domain/schema.js";

test("normalizes a valid reply payload", () => {
  const result = normalizeReplyResult({
    replyOptions: [
      { text: "이번엔 어려울 것 같아.", toneLabel: "정중한 버전", whyItWorks: "짧고 분명함" },
      { text: "이번엔 안 될 것 같아.", toneLabel: "자연스러운 버전", whyItWorks: "부담 없이 선을 긋음" },
      { text: "이번 요청은 어렵겠어.", toneLabel: "단호한 버전", whyItWorks: "재요청 여지를 줄임" }
    ],
    avoidPhrases: ["다음에 보자"],
    openDoorRisk: "low",
    alternativeDifference: "대안을 넣으면 부드러워지지만 여지가 생길 수 있다."
  });

  assert.equal(result?.replyOptions.length, 3);
  assert.equal(result?.replyOptions[0].toneLabel, "정중한 버전");
  assert.equal(result?.replyOptions[0].whyItWorks, "짧고 분명함");
  assert.equal(result?.avoidPhrases[0], "다음에 보자");
  assert.equal(result?.openDoorRisk, "low");
  assert.match(result?.alternativeDifference ?? "", /대안을 넣으면/);
});

test("rejects duplicate reply texts", () => {
  const result = normalizeReplyResult({
    replyOptions: [
      { text: "안 될 것 같아.", toneLabel: "정중한 버전", whyItWorks: "짧다" },
      { text: "안 될 것 같아.", toneLabel: "자연스러운 버전", whyItWorks: "자연스럽다" },
      { text: "이번엔 어렵겠어.", toneLabel: "단호한 버전", whyItWorks: "분명하다" }
    ],
    avoidPhrases: [],
    openDoorRisk: "low",
    alternativeDifference: "차이가 있다."
  });

  assert.equal(result, null);
});
