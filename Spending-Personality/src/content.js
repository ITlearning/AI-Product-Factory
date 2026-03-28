export const PREVIEW_CASES = [
  {
    label: "야근 후 회복 모드",
    title: "하루 끝에 스스로를 달랜 날",
    note: "야근하고 돌아오는 길, 오늘은 조금 지친 날",
    transactions: [
      "07:42 신한 체크 GS25 성수점 4,800원",
      "12:15 현대카드 샐러드랩 11,900원",
      "18:34 카카오T 택시 14,200원",
      "21:08 배민 디저트 9,500원"
    ]
  },
  {
    label: "속도전 생존 모드",
    title: "시간을 사서 하루를 밀어낸 날",
    note: "이동과 빠른 해결이 계속 필요했던 하루",
    transactions: [
      "08:10 지하철 1,400원",
      "12:20 편의점 삼각김밥 2,300원",
      "18:50 카카오T 택시 17,000원",
      "21:14 배달 덮밥 14,000원"
    ]
  },
  {
    label: "잔지출 산책 모드",
    title: "필요한 걸 조금씩 챙긴 날",
    note: "큰 결제는 없었지만 자잘한 선택이 자주 나온 날",
    transactions: [
      "09:05 신한 체크 GS25 성수점 3,200원",
      "11:40 프린트 1,500원",
      "15:20 다이소 4,000원",
      "20:45 약국 6,800원"
    ]
  }
];

export const SAMPLE_CASE = PREVIEW_CASES[0];
export const SAMPLE_TRANSACTIONS = SAMPLE_CASE.transactions;
export const SAMPLE_NOTE = SAMPLE_CASE.note;

export const INPUT_PLACEHOLDER = [
  "예)",
  "07:42 카카오뱅크 체크 GS25 성수점 4,800원",
  "12:15 팀 점심 샐러드랩 11,900원",
  "18:34 카카오T 택시 14,200원",
  "",
  "메모 줄이 섞여도 괜찮아요. 금액이 있는 줄부터 읽습니다."
].join("\n");

export const HERO_POINTS = [
  "붙여넣기 한 번으로 하루 소비 흐름을 읽는 MVP",
  "생성 뒤에는 캐릭터명, 근거 소비, 내일의 한 수를 결과 우선으로 정리",
  "저장/공유 카드를 본문과 다른 시각 레이어로 분리해 빠르게 읽히는 화면"
];

export const SHELL_MILESTONES = [
  {
    label: "AI-13 범위",
    title: "붙여넣기 중심 입력 완성",
    copy: "실제 입력, 메모, 버튼 상태, 생성 전 기대감 프리뷰를 한 화면 안에서 연결합니다."
  },
  {
    label: "AI-15 범위",
    title: "결과 우선 화면",
    copy: "생성 후에는 캐릭터명, 근거 소비, 내일의 한 수, 저장/공유 카드를 한 흐름으로 읽히게 합니다."
  },
  {
    label: "후속 task",
    title: "저장과 히스토리 확장",
    copy: "결과 카드 저장/공유 액션과 최근 캐릭터 히스토리를 붙여 하루 기록 경험을 완성합니다."
  }
];
