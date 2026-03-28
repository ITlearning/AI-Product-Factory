export const SITUATION_OPTIONS = [
  { value: "promise", label: "약속" },
  { value: "favor", label: "부탁" }
];

export const BLOCKER_OPTIONS = [
  { value: "guilt", label: "미안해서 시작이 안 돼요" },
  { value: "tone-anxiety", label: "너무 차갑게 보일까 걱정돼요" },
  { value: "overexplaining", label: "말이 길어질까 봐 걱정돼요" }
];

export const REPLY_TONE_OPTIONS = [
  { value: "soft", label: "부드럽게" },
  { value: "polite-firm", label: "예의 있게 확실하게" },
  { value: "short", label: "짧게 끝내기" }
];

export const SUPPORTED_SITUATION_VALUES = new Set(
  SITUATION_OPTIONS.map((option) => option.value)
);

export const SUPPORTED_BLOCKER_VALUES = new Set(
  BLOCKER_OPTIONS.map((option) => option.value)
);

export const SUPPORTED_REPLY_TONE_VALUES = new Set(
  REPLY_TONE_OPTIONS.map((option) => option.value)
);
