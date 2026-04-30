import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { evaluateSeoulYouthRent2026 } from "../../src/eligibility/evaluator.js";

/**
 * 자격 OK 기본 입력 (1인 가구, 서울, 1995.6.15 출생, 보증금 500만, 월세 40만, 소득 100%)
 * 각 테스트는 이 베이스를 spread해서 필요한 필드만 덮어쓴다.
 */
const BASE_OK_INPUT = {
  birthDate: "1995-06-15",
  militaryMonths: 0,
  residence: "서울",
  householdType: "single",
  hasNewlywedChildren: false,
  hasSinglParentCert: false,
  hasFraudVictimCert: false,
  youthSafeHousingType: null,
  householdSize: 1,
  monthlyIncomeWon: 2_220_000, // 1인가구 100%
  depositWon: 5_000_000,
  monthlyRentWon: 400_000,
  generalAssetWon: 50_000_000,
  vehicleValueWon: 0,
  ownsHome: false,
  landlordIsParent: false,
  allCotenantsApplying: false,
  receivingNationalYouthRent: false,
  previouslyReceivedSeoulRent: false,
  basicLivingRecipient: false,
};

// =================================================================
// Happy path — 4 tier 매칭
// =================================================================

describe("Happy path: 4 tier 매칭", () => {
  test("Tier 1 — 보증금 500만, 월세 40만, 소득 100% → rank 1, ratio 0.35", () => {
    const result = evaluateSeoulYouthRent2026(BASE_OK_INPUT);
    assert.equal(result.eligible, true);
    assert.deepEqual(result.tier, { rank: 1, ratio: 0.35 });
    assert.equal(result.primaryReason, null);
    assert.equal(result.incomePercent, 100);
  });

  test("Tier 2 — 보증금 1000만, 월세 50만, 소득 130% → rank 2, ratio 0.30", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      depositWon: 10_000_000,
      monthlyRentWon: 500_000,
      monthlyIncomeWon: 2_886_000, // 1인 130%
    });
    assert.equal(result.eligible, true);
    assert.deepEqual(result.tier, { rank: 2, ratio: 0.30 });
  });

  test("Tier 3 — 보증금 2000만, 월세 60만 → rank 3, ratio 0.20", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      depositWon: 20_000_000,
      monthlyRentWon: 600_000,
    });
    assert.equal(result.eligible, true);
    assert.deepEqual(result.tier, { rank: 3, ratio: 0.20 });
  });

  test("Tier 4 — 보증금 8000만, 월세 60만 → rank 4, ratio 0.15", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      depositWon: 80_000_000,
      monthlyRentWon: 600_000,
    });
    assert.equal(result.eligible, true);
    assert.deepEqual(result.tier, { rank: 4, ratio: 0.15 });
  });
});

// =================================================================
// 연령 (군복무 보정 포함)
// =================================================================

describe("연령", () => {
  test("1985.6.30 출생 + 군복무 0개월 → 연령 초과 FAIL", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      birthDate: "1985-06-30",
      militaryMonths: 0,
    });
    assert.equal(result.eligible, false);
    assert.match(result.primaryReason, /연령/);
    // 다른 지역 추천이 아닌 국토부 한시지원 추천이 와야 한다
    assert.ok(
      result.alternativeProgramSuggestions.some((s) => s.includes("국토부")),
      `expected 국토부 한시지원 안내, got ${JSON.stringify(result.alternativeProgramSuggestions)}`
    );
  });

  test("1985.6.30 출생 + 군복무 36개월 → 연령 통과 (3년 연장 적용)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      birthDate: "1985-06-30",
      militaryMonths: 36,
    });
    // 보정 출생일 1988.6.30 → 1986.1.1 이후 → 통과
    assert.equal(result.eligible, true);
    // 36개월 군복무는 병적증명서 추가 필요
    assert.ok(
      result.requiredDocuments.some((d) => d.includes("병적증명서") || d.includes("병역")),
      `expected 병적증명서 in documents, got ${JSON.stringify(result.requiredDocuments)}`
    );
  });

  test("1985.6.30 출생 + 군복무 6개월 → 연령 미달 FAIL (1년 연장 안 됨)", () => {
    // 6개월은 1년 미만 → 보정 0년 → 1985.6.30 그대로 → ageMin(1986.1.1) 이전 → FAIL
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      birthDate: "1985-06-30",
      militaryMonths: 6,
    });
    assert.equal(result.eligible, false);
    assert.match(result.primaryReason, /연령/);
  });

  test("2008.1.1 출생 → 연령 미달 FAIL (만 19세 미만)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      birthDate: "2008-01-01",
    });
    assert.equal(result.eligible, false);
    assert.match(result.primaryReason, /연령|만 19세/);
  });
});

// =================================================================
// 보증금 / 월세
// =================================================================

describe("보증금/월세", () => {
  test("보증금 9000만 → FAIL (8천만 초과)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      depositWon: 90_000_000,
    });
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("보증금")));
  });

  test("보증금 5000만 + 월세 70만 → 환산식 통과 (88.75만 ≤ 90만)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      depositWon: 50_000_000,
      monthlyRentWon: 700_000,
    });
    // 5000만 × 0.045 / 12 = 187,500 + 700,000 = 887,500 ≤ 900,000
    assert.equal(result.eligible, true);
    assert.equal(result.tier.rank, 4);
  });

  test("보증금 8000만 + 월세 70만 → 환산식 실패 (100만 > 90만)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      depositWon: 80_000_000,
      monthlyRentWon: 700_000,
    });
    // 8000만 × 0.045 / 12 = 300,000 + 700,000 = 1,000,000 > 900,000
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("월세")));
  });
});

// =================================================================
// 소득
// =================================================================

describe("소득 (중위소득)", () => {
  test("1인 + 월 100만원 → 약 45% < 48% → FAIL + 주거급여 추천", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      monthlyIncomeWon: 1_000_000,
    });
    assert.equal(result.eligible, false);
    assert.ok(result.incomePercent < 48);
    assert.ok(result.allReasons.some((r) => r.includes("48%") || r.includes("주거급여")));
    assert.ok(
      result.alternativeProgramSuggestions.some((s) => s.includes("주거급여")),
      `expected 주거급여 alt, got ${JSON.stringify(result.alternativeProgramSuggestions)}`
    );
  });

  test("1인 + 월 350만원 → 약 158% > 150% → FAIL", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      monthlyIncomeWon: 3_500_000,
    });
    assert.equal(result.eligible, false);
    assert.ok(result.incomePercent > 150);
    assert.ok(result.allReasons.some((r) => r.includes("150%")));
  });
});

// =================================================================
// 재산
// =================================================================

describe("재산", () => {
  test("일반재산 1.4억 → FAIL (1.3억 초과)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      generalAssetWon: 140_000_000,
    });
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("일반재산") || r.includes("1.3억")));
  });

  test("차량 시가 2,600만 → FAIL (2,500만 이상)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      vehicleValueWon: 26_000_000,
    });
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("차량") || r.includes("2,500")));
  });

  test("차량 시가 정확히 2,500만 → FAIL (이상 = 미만 아님)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      vehicleValueWon: 25_000_000,
    });
    assert.equal(result.eligible, false);
  });
});

// =================================================================
// 가구형태 5종
// =================================================================

describe("가구형태", () => {
  test("청년신혼부부 + 자녀 있음 → FAIL (무자녀 조건)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      householdType: "young-newlywed",
      hasNewlywedChildren: true,
      householdSize: 2,
      monthlyIncomeWon: 3_680_000, // 2인 100%
    });
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("무자녀") || r.includes("자녀")));
  });

  test("한부모 + 증명서 X → FAIL", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      householdType: "single-parent",
      hasSinglParentCert: false,
      householdSize: 2,
      monthlyIncomeWon: 3_680_000,
    });
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("한부모")));
  });

  test("한부모 + 증명서 O → 자격 OK + 증명서가 서류에 추가", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      householdType: "single-parent",
      hasSinglParentCert: true,
      householdSize: 2,
      monthlyIncomeWon: 3_680_000,
    });
    assert.equal(result.eligible, true);
    assert.ok(
      result.requiredDocuments.some((d) => d.includes("한부모가족증명서")),
      `expected 한부모가족증명서, got ${JSON.stringify(result.requiredDocuments)}`
    );
  });

  test("전세사기 결정문 O → 자격 OK + 결정문 서류 추가", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      householdType: "fraud-victim",
      hasFraudVictimCert: true,
    });
    assert.equal(result.eligible, true);
    assert.ok(result.requiredDocuments.some((d) => d.includes("전세사기")));
  });

  test("청년안심주택 public → FAIL (공공임대 제외)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      householdType: "youth-safe-housing",
      youthSafeHousingType: "public",
    });
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("공공임대") || r.includes("청년안심")));
  });

  test("청년안심주택 private → 자격 OK", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      householdType: "youth-safe-housing",
      youthSafeHousingType: "private",
    });
    assert.equal(result.eligible, true);
  });
});

// =================================================================
// Exclusions
// =================================================================

describe("Exclusions", () => {
  test("임대인 = 부모 → FAIL", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      landlordIsParent: true,
    });
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("부모")));
  });

  test("공동임차인 모두 신청 → FAIL", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      allCotenantsApplying: true,
    });
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("공동임차인")));
  });

  test("국토부 한시지원 수혜 중 → FAIL", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      receivingNationalYouthRent: true,
    });
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("국토부") || r.includes("한시")));
  });

  test("서울시 기수령자 → FAIL", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      previouslyReceivedSeoulRent: true,
    });
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("생애 1회") || r.includes("이미 받")));
  });

  test("국기초 수급자 → FAIL", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      basicLivingRecipient: true,
    });
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("국민기초") || r.includes("국기초")));
  });

  test("주택 소유 → FAIL", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      ownsHome: true,
    });
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("주택") || r.includes("소유")));
  });
});

// =================================================================
// 거주지
// =================================================================

describe("거주지", () => {
  test("부산 거주 → FAIL + 다른 지역 정책 추천", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      residence: "부산",
    });
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("서울")));
    assert.ok(
      result.alternativeProgramSuggestions.some((s) => s.includes("다른 지역")),
      `expected 다른 지역 안내, got ${JSON.stringify(result.alternativeProgramSuggestions)}`
    );
  });
});

// =================================================================
// 서류
// =================================================================

describe("서류 (requiredDocuments)", () => {
  test("자격 OK 기본 → 4종 필수 서류 모두 포함", () => {
    const result = evaluateSeoulYouthRent2026(BASE_OK_INPUT);
    assert.equal(result.eligible, true);
    assert.equal(result.requiredDocuments.length, 4);
    assert.ok(result.requiredDocuments.some((d) => d.includes("임대차계약서")));
    assert.ok(result.requiredDocuments.some((d) => d.includes("이체확인증")));
    assert.ok(result.requiredDocuments.some((d) => d.includes("가족관계증명서")));
    assert.ok(result.requiredDocuments.some((d) => d.includes("행정정보")));
  });

  test("자격 OK + 군복무 12개월 이상 → 병적증명서 추가", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      militaryMonths: 24,
    });
    assert.equal(result.eligible, true);
    assert.ok(
      result.requiredDocuments.some((d) => d.includes("병적증명서") || d.includes("병역")),
      `expected 병적증명서, got ${JSON.stringify(result.requiredDocuments)}`
    );
  });

  test("자격 OK + 한부모 → 한부모가족증명서 추가", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      householdType: "single-parent",
      hasSinglParentCert: true,
      householdSize: 2,
      monthlyIncomeWon: 3_680_000,
    });
    assert.equal(result.eligible, true);
    assert.ok(result.requiredDocuments.some((d) => d.includes("한부모가족증명서")));
  });

  test("자격 X → requiredDocuments는 빈 배열", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      ownsHome: true,
    });
    assert.equal(result.eligible, false);
    assert.deepEqual(result.requiredDocuments, []);
  });
});

// =================================================================
// Tier 매칭 fallback (4구간 보호)
// =================================================================

describe("Tier 매칭", () => {
  test("보증금 7000만 + 월세 30만 → 4구간 매칭 (rank=4)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      depositWon: 70_000_000,
      monthlyRentWon: 300_000,
    });
    assert.equal(result.eligible, true);
    assert.equal(result.tier.rank, 4);
    assert.equal(result.tier.ratio, 0.15);
  });

  test("Tier 1 경계 — 보증금 500만 + 월세 40만 + 소득 120% → rank 1", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      depositWon: 5_000_000,
      monthlyRentWon: 400_000,
      monthlyIncomeWon: 2_664_000, // 1인 120%
    });
    assert.equal(result.eligible, true);
    assert.equal(result.tier.rank, 1);
  });

  test("Tier 2 경계 — 소득 121% → rank 2 (1구간 incomeRange 120% 초과)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      depositWon: 5_000_000,
      monthlyRentWon: 400_000,
      monthlyIncomeWon: 2_686_200, // 1인 약 121%
    });
    assert.equal(result.eligible, true);
    // 1구간 income 한도(120%) 초과 → 2구간 매칭
    assert.equal(result.tier.rank, 2);
  });
});

// =================================================================
// 다중 사유 (allReasons 검증)
// =================================================================

describe("다중 사유", () => {
  test("거주지 + 보증금 + 재산 모두 위반 → allReasons 3개 이상", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      residence: "경기",
      depositWon: 90_000_000,
      generalAssetWon: 200_000_000,
    });
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.length >= 3, `expected 3+ reasons, got ${result.allReasons.length}`);
  });

  test("자격 OK 시 allReasons는 빈 배열", () => {
    const result = evaluateSeoulYouthRent2026(BASE_OK_INPUT);
    assert.equal(result.eligible, true);
    assert.deepEqual(result.allReasons, []);
    assert.deepEqual(result.alternativeProgramSuggestions, []);
  });
});

// =================================================================
// 가구원수별 중위소득 계산 검증
// =================================================================

describe("중위소득 계산", () => {
  test("2인가구 + 월 368만 → 100%", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      householdSize: 2,
      monthlyIncomeWon: 3_680_000,
    });
    assert.equal(result.incomePercent, 100);
  });

  test("4인가구 + 월 572만 → 100%", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      householdSize: 4,
      monthlyIncomeWon: 5_720_000,
    });
    assert.equal(result.incomePercent, 100);
  });

  test("1인가구 + 월 약 107만 → 약 48% 경계 통과", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      monthlyIncomeWon: 1_065_600, // 정확히 48%
    });
    assert.equal(result.eligible, true);
    assert.equal(result.incomePercent, 48);
  });
});
