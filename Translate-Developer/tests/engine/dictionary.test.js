import test from "node:test";
import assert from "node:assert/strict";

import { getDictionary } from "../../src/engine/dictionaries/index.js";
import { translateWithRules } from "../../src/engine/index.js";

test("getDictionary('developer')가 TERM_DICTIONARY를 반환한다", () => {
  const dict = getDictionary("developer");

  assert.ok(Array.isArray(dict.TERM_DICTIONARY));
  assert.ok(dict.TERM_DICTIONARY.length > 0);
});

test("getDictionary('designer')가 designer 전용 사전을 반환한다", () => {
  const designerDict = getDictionary("designer");
  const developerDict = getDictionary("developer");

  assert.ok(Array.isArray(designerDict.TERM_DICTIONARY));
  assert.ok(designerDict.TERM_DICTIONARY.length > 0);
  assert.notDeepEqual(designerDict.TERM_DICTIONARY, developerDict.TERM_DICTIONARY);
});

test("getDictionary('unknown')가 developer fallback을 반환한다", () => {
  const unknownDict = getDictionary("unknown");
  const developerDict = getDictionary("developer");

  assert.deepEqual(unknownDict.TERM_DICTIONARY, developerDict.TERM_DICTIONARY);
});

test("translateWithRules는 categoryId 없이 호출해도 동작한다 (기본값 'developer')", () => {
  const result = translateWithRules("배포 후 결제 API에서 타임아웃이 발생했습니다.");

  assert.ok(result.rewrittenMessage);
});

test("translateWithRules에 categoryId='designer' 전달 시 designer 사전을 사용한다", () => {
  const result = translateWithRules(
    "핸드오프 완료 후 스펙 문서에 토큰 값이 빠져 있어.",
    "pm-planner",
    "designer"
  );

  assert.ok(result.rewrittenMessage);
});
