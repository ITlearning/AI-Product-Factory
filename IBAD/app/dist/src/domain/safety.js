const OPEN_DOOR_PATTERN = /다음에|나중에|시간 되면|기회 되면|언젠가|다음엔 보자/;
const APOLOGETIC_PATTERN = /미안|죄송/g;
const ROMANTIC_PATTERN = /남자친구|여자친구|애인|썸|소개팅/;
const FAMILY_PATTERN = /엄마|아빠|부모님|가족|언니|오빠|누나|형|동생/;
const WORK_PATTERN = /회사|직장|팀장|상사|부장|과장|대표|거래처|업무/;
const FOLLOW_UP_PATTERN = /다시 뭐라고|한번 거절했는데|후속 답장|이어서 답장|답장 이어서/;

/**
 * @param {{ relationshipType: string, situationType: string, input: string }} payload
 * @returns {{ supported: true } | { supported: false, code: "UNSUPPORTED_SCOPE", message: string }}
 */
export function detectUnsupportedScope(payload) {
  const source = `${payload.relationshipType} ${payload.situationType} ${payload.input}`;

  if (ROMANTIC_PATTERN.test(source) || FAMILY_PATTERN.test(source) || WORK_PATTERN.test(source)) {
    return unsupported();
  }

  if (FOLLOW_UP_PATTERN.test(source)) {
    return unsupported();
  }

  return { supported: true };
}

/**
 * @param {string} text
 * @param {{ includeAlternative: boolean }} options
 * @returns {{ code: "OPEN_DOOR_PHRASE" | "TOO_APOLOGETIC" | "TOO_LONG", phrase: string }[]}
 */
export function findReplySafetyIssues(text, options) {
  /** @type {{ code: "OPEN_DOOR_PHRASE" | "TOO_APOLOGETIC" | "TOO_LONG", phrase: string }[]} */
  const issues = [];
  const openDoorMatch = text.match(OPEN_DOOR_PATTERN);

  if (!options.includeAlternative && openDoorMatch) {
    issues.push({
      code: "OPEN_DOOR_PHRASE",
      phrase: openDoorMatch[0]
    });
  }

  if ((text.match(APOLOGETIC_PATTERN) ?? []).length >= 2) {
    issues.push({
      code: "TOO_APOLOGETIC",
      phrase: "미안"
    });
  }

  if (text.length > 120) {
    issues.push({
      code: "TOO_LONG",
      phrase: text.slice(0, 24)
    });
  }

  return issues;
}

function unsupported() {
  return {
    supported: false,
    code: "UNSUPPORTED_SCOPE",
    message: "현재 버전은 친구/지인 대상의 약속·부탁 거절만 지원합니다."
  };
}
