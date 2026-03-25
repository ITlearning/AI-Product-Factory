export const AUDIENCE_OPTIONS = [
  {
    id: "pm-planner",
    label: "PM/기획자",
    description: "기술 용어와 일정/사용자 영향이 먼저 보이게 풀어드립니다."
  },
  {
    id: "designer",
    label: "디자이너",
    description: "화면, 플로우, 작업 영향이 잘 보이게 풀어드립니다."
  },
  {
    id: "non-developer",
    label: "비개발자",
    description: "기술 표현을 일반적인 말로 쉽게 풀어드립니다."
  }
];

export const DEFAULT_AUDIENCE = AUDIENCE_OPTIONS[0].id;

/**
 * @param {unknown} value
 * @returns {value is import("../engine/types.js").AudienceId}
 */
export function isAudienceId(value) {
  return AUDIENCE_OPTIONS.some((option) => option.id === value);
}

/**
 * @param {unknown} value
 * @returns {import("../engine/types.js").AudienceId}
 */
export function normalizeAudience(value) {
  return isAudienceId(value) ? value : DEFAULT_AUDIENCE;
}

/**
 * @param {import("../engine/types.js").AudienceId} audience
 */
export function getAudienceOption(audience) {
  return AUDIENCE_OPTIONS.find((option) => option.id === audience) ?? AUDIENCE_OPTIONS[0];
}
