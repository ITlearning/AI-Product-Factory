export const HERO_POINTS = [
  "캐릭터명과 한 줄 요약을 첫 시야에 바로 배치",
  "근거 소비 2~3개와 내일의 한 수를 짧게 분리 정리",
  "저장/공유용 카드를 결과 본문과 다른 시각 레이어로 분리"
];

export const PREVIEW_CASES = [
  {
    label: "야근 후 회복 모드",
    title: "하루 끝에 스스로를 달랜 날",
    note: "야근하고 돌아오는 길, 오늘은 조금 지친 날",
    transactions: [
      "07:42 편의점 4,800원",
      "12:15 회사 근처 샐러드 11,900원",
      "18:34 택시 14,200원",
      "21:08 배달 디저트 9,500원"
    ]
  },
  {
    label: "속도전 생존 모드",
    title: "시간을 사서 하루를 밀어낸 날",
    note: "이동과 빠른 해결이 계속 필요했던 하루",
    transactions: [
      "08:10 지하철 1,400원",
      "12:20 편의점 삼각김밥 2,300원",
      "18:50 택시 17,000원",
      "21:14 배달 덮밥 14,000원"
    ]
  },
  {
    label: "잔지출 산책 모드",
    title: "필요한 걸 조금씩 챙긴 날",
    note: "큰 결제는 없었지만 자잘한 선택이 자주 나온 날",
    transactions: [
      "09:05 편의점 3,200원",
      "11:40 프린트 1,500원",
      "15:20 다이소 4,000원",
      "20:45 약국 6,800원"
    ]
  }
];

export const SAMPLE_CASE = PREVIEW_CASES[0];
export const SAMPLE_TRANSACTIONS = SAMPLE_CASE.transactions;
export const SAMPLE_NOTE = SAMPLE_CASE.note;
