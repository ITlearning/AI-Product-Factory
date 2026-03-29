export const BRAND_COPY = {
  title: "Translate-Developer",
  subtitle: "Role-Aware"
};

export const COMPOSER_COPY = {
  title: "개발자 메시지 해설기",
  description: "한 줄만 넣기보다, 앞뒤 슬랙 대화와 맥락을 함께 넣을수록 더 정확하게 풀어드립니다.",
  textareaLabel: "원문 또는 대화 내용",
  textareaHelp: "한 줄만 넣지 말고, 문제 설명과 앞뒤 맥락까지 함께 넣어 주세요.",
  textareaPlaceholder: "한 줄만 넣지 말고, 문제 설명과 앞뒤 맥락까지 함께 넣어 주세요.",
  submitIdleLabel: "쉽게 풀어보기",
  submitLoadingLabel: "AI 설명 정리 중..."
};

export const EXAMPLE_PANEL_COPY = {
  title: "빠른 예시",
  description: "앞뒤 맥락이 조금 붙은 대화형 예시로 바로 확인할 수 있습니다."
};

export const GUIDANCE_COPY = {
  title: "더 알려주면 정확해지는 부분",
  items: [
    "원문 한 줄보다 앞뒤 대화를 같이 넣기",
    "누가 영향을 받는지 언급된 문장 함께 넣기",
    "아직 모르는 부분도 그대로 두기"
  ]
};

export const RESULT_COPY = {
  title: "결과",
  descriptionSuffix: "가 먼저 이해할 수 있게 다시 풀어썼습니다.",
  summaryLabel: "쉽게 다시 쓴 내용",
  glossaryTitle: "전문 용어 풀이",
  glossaryDescription: "어려운 표현을 없애기보다, 어떤 뜻인지 바로 이해할 수 있게 풀어드립니다.",
  glossaryEmpty: "지금 문장에는 따로 풀어야 할 전문 용어가 많지 않아요.",
  glossaryColumns: {
    term: "원본 표현",
    explanation: "쉽게 풀면"
  },
  footerBySource: {
    ai: "AI 설명이 우선 적용됐습니다. 응답 형식이 맞지 않거나 호출이 실패하면 기본 설명 모드로 전환됩니다.",
    fallback: "기본 설명 모드가 적용됐습니다. AI 응답이 복구되면 같은 입력으로 다시 시도해 보세요.",
    idle: "AI 설명이 우선 적용되고, 실패하면 기본 설명 모드로 자동 전환됩니다."
  }
};

export const RESULT_TABS = [
  { id: "rewritten", label: "쉽게 다시 쓴 내용" },
  { id: "glossary", label: "전문 용어 풀이" },
  { id: "impact", label: "이 대화에서 보이는 영향" },
  { id: "context", label: "더 알려주면 정확해지는 부분" }
];

export const RESULT_PLACEHOLDERS = {
  rewritten: "입력한 메시지를 쉬운 한국어로 다시 풀어씁니다.",
  impact: "입력에 직접 나온 영향만 정리합니다.",
  context: "추정 대신, 더 필요한 맥락을 부드럽게 알려줍니다."
};
