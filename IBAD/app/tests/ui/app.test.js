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

  assert.match(markup, /답장을 못 보내고 있다면, 여기서 시작하세요/);
  assert.match(markup, /받은 메시지를 붙여넣어 주세요/);
  assert.match(markup, /약속/);
  assert.match(markup, /부탁/);
  assert.match(markup, /답장 만들기/);
  assert.doesNotMatch(markup, /관계 타입/);
  assert.doesNotMatch(markup, /거절 강도/);
  assert.doesNotMatch(markup, /바로 시작할 수 있는 답장/);
  assert.doesNotMatch(markup, /복사하기/);
  assert.doesNotMatch(markup, /피해야 할 표현/);
  assert.doesNotMatch(markup, /여지 남김 여부/);
});

test("updates form fields in state", () => {
  const state = updateField(createInitialState(), "situationType", "favor");

  assert.equal(state.situationType, "favor");
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
            { text: "오늘은 좀 어려울 것 같아.", toneLabel: "부드럽게", whyItWorks: "미안함은 남기고 결론은 분명하게 말한다." },
            { text: "이번엔 어려워. 고마운데 패스할게.", toneLabel: "예의 있게 확실하게", whyItWorks: "예의는 지키면서 재요청 여지를 줄인다." },
            { text: "이번엔 어려워.", toneLabel: "짧게 끝내기", whyItWorks: "짧게 마무리해 왕복을 줄인다." }
          ]
        }
      })
    }
  );

  const markup = renderAppMarkup(state);
  assert.match(markup, /바로 시작할 수 있는 답장/);
  assert.match(markup, /부드럽게/);
  assert.match(markup, /예의 있게 확실하게/);
  assert.match(markup, /짧게 끝내기/);
  assert.doesNotMatch(markup, /피해야 할 표현/);
  assert.doesNotMatch(markup, /여지 남김 여부/);
  assert.match(markup, /복사하기/);
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
