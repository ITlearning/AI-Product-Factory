import test from "node:test";
import assert from "node:assert/strict";

import {
  createInitialState,
  submitReplyRequest,
  updateField
} from "../../src/ui/state.js";
import { renderAppMarkup } from "../../src/ui/templates.js";

test("renders the IBAD app shell", () => {
  const markup = renderAppMarkup(createInitialState());

  assert.match(markup, /이번엔 안 돼/);
  assert.match(markup, /관계 타입/);
  assert.match(markup, /답장 만들기/);
  assert.match(markup, /예의 있게 확실하게/);
});

test("updates form fields in state", () => {
  const state = updateField(createInitialState(), "relationshipType", "ambiguous");

  assert.equal(state.relationshipType, "ambiguous");
});

test("renders generated reply cards", async () => {
  const state = await submitReplyRequest(
    {
      ...createInitialState(),
      input: "친구가 오늘 저녁에 보자고 했는데 쉬고 싶다."
    },
    {
      requestReplySet: async () => ({
        ok: true,
        result: {
          replyOptions: [
            { text: "오늘은 좀 쉬고 싶어서 이번엔 어려울 것 같아.", toneLabel: "정중한 버전", whyItWorks: "부드럽게 선을 긋는다." },
            { text: "오늘은 패스할게. 이번엔 안 될 것 같아.", toneLabel: "자연스러운 버전", whyItWorks: "짧고 분명하다." },
            { text: "오늘은 안 될 것 같아.", toneLabel: "단호한 버전", whyItWorks: "여지를 줄인다." }
          ],
          avoidPhrases: ["다음에 보자"],
          openDoorRisk: "낮음",
          alternativeDifference: "대안을 넣지 않으면 더 깔끔하게 끝난다."
        }
      })
    }
  );

  const markup = renderAppMarkup(state);
  assert.match(markup, /정중한 버전/);
  assert.match(markup, /피해야 할 표현/);
  assert.match(markup, /여지 남김 여부/);
  assert.match(markup, /대안을 넣었을 때 \/ 안 넣었을 때/);
  assert.match(markup, /복사/);
});

test("renders unsupported-scope feedback", async () => {
  const state = await submitReplyRequest(
    {
      ...createInitialState(),
      input: "팀장님이 오늘 저녁에 같이 가자고 했다."
    },
    {
      requestReplySet: async () => ({
        ok: false,
        code: "UNSUPPORTED_SCOPE",
        message: "현재 버전은 친구/지인 대상의 약속·부탁 거절만 지원합니다."
      })
    }
  );

  assert.equal(state.feedback?.type, "warning");
  const markup = renderAppMarkup(state);
  assert.match(markup, /현재 버전은 친구\/지인 대상의 약속·부탁 거절만 지원합니다/);
});

test("renders request failures as error feedback", async () => {
  const state = await submitReplyRequest(
    {
      ...createInitialState(),
      input: "친구 부탁을 거절하고 싶다."
    },
    {
      requestReplySet: async () => ({
        ok: false,
        code: "REQUEST_FAILED",
        message: "답장 생성 요청에 실패했습니다."
      })
    }
  );

  assert.equal(state.feedback?.type, "error");
});
