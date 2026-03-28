export const RELATIONSHIP_OPTIONS = [
  { value: "close-friend", label: "친한 친구" },
  { value: "just-friend", label: "그냥 친구" },
  { value: "ambiguous", label: "애매한 사이" },
  { value: "barely-close", label: "거의 안 친함" }
];

export const SITUATION_OPTIONS = [
  { value: "promise", label: "약속" },
  { value: "favor", label: "부탁" }
];

export const BLOCKER_OPTIONS = [
  { value: "guilt", label: "미안해서 시작이 안 돼요" },
  { value: "tone-anxiety", label: "너무 차갑게 보일까 걱정돼요" },
  { value: "overexplaining", label: "말이 길어질까 봐 걱정돼요" }
];

export const STRENGTH_OPTIONS = [
  { value: "soft", label: "부드럽게" },
  { value: "polite-firm", label: "예의 있게 확실하게" },
  { value: "firm", label: "단호하게" }
];

export const SUPPORTED_RELATIONSHIP_VALUES = new Set(
  RELATIONSHIP_OPTIONS.map((option) => option.value)
);

export const SUPPORTED_SITUATION_VALUES = new Set(
  SITUATION_OPTIONS.map((option) => option.value)
);

export const SUPPORTED_BLOCKER_VALUES = new Set(
  BLOCKER_OPTIONS.map((option) => option.value)
);

export const SUPPORTED_STRENGTH_VALUES = new Set(
  STRENGTH_OPTIONS.map((option) => option.value)
);
