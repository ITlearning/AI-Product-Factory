import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { evaluateSeoulYouthRent2026 } from "../../src/eligibility/evaluator.js";

/**
 * 자격 OK 기본 입력 (1인 가구, 서울, 1995.6.15 출생, 보증금 500만, 월세 40만, 소득 100%)
 * 각 테스트는 이 베이스를 spread해서 필요한 필드만 덮어쓴다.
 */
const BASE_OK_INPUT = {
  birthDate: "1995-06-15",
  isVeteran: false,
  militaryMonths: 0,
  residence: "서울",
  householdType: "single",
  hasNewlywedChildren: false,
  hasSinglParentCert: false,
  hasFraudVictimCert: false,
  youthSafeHousingType: null,
  householdSize: 1,
  monthlyIncomeWon: 2_220_000, // 1인가구 약 86.6% (48% 초과 ~ 120% 이하 범위)
  depositWon: 5_000_000,
  monthlyRentWon: 400_000,
  generalAssetWon: 50_000_000,
  vehicleValueWon: 0,
  ownsHome: false,
  landlordRelation: "other",
  allCotenantsApplying: false,
  receivingNationalYouthRent: false,
  previouslyReceivedSeoulRent: false,
  basicLivingRecipient: false,
  nationalityStatus: "korean",
  receivingDistrictRent: false,
  receivingSeoulYouthAllowance: false,
  receivingTransitionYouthSupport: false,
  receivingSeoulHousingVoucher: false,
  inPublicHousing: false,
  bothNewlywedsApplying: false,
  receivingOtherSimilarProgram: false,
};

// =================================================================
// Happy path — 4 tier 매칭
// =================================================================

describe("Happy path: 4 tier 매칭", () => {
  test("Tier 1 — 보증금 500만, 월세 40만, 소득 1구간 → rank 1, ratio 0.35", () => {
    const result = evaluateSeoulYouthRent2026(BASE_OK_INPUT);
    assert.equal(result.eligible, true);
    assert.deepEqual(result.tier, { rank: 1, ratio: 0.35 });
    assert.equal(result.primaryReason, null);
  });

  test("Tier 2 — 보증금 1000만, 월세 50만, 소득 130% → rank 2, ratio 0.30", () => {
    // 1인 130% 절대값 = 약 3,333,509원 → 120% 초과 ~ 150% 이하
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      depositWon: 10_000_000,
      monthlyRentWon: 500_000,
      monthlyIncomeWon: 3_333_509,
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
// 연령 (군복무 계단식 보정)
// =================================================================

describe("연령 (군복무 계단식 보정)", () => {
  test("1985.6.30 + isVeteran false + 0개월 → FAIL (보정 0년)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      birthDate: "1985-06-30",
      isVeteran: false,
      militaryMonths: 0,
    });
    assert.equal(result.eligible, false);
    assert.match(result.primaryReason, /연령/);
    assert.ok(
      result.alternativeProgramSuggestions.some((s) => s.includes("국토부")),
      `expected 국토부 한시지원 안내, got ${JSON.stringify(result.alternativeProgramSuggestions)}`
    );
  });

  test("1985.6.30 + isVeteran true + 0개월 → FAIL (보정 0 — 의무복무 0개월)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      birthDate: "1985-06-30",
      isVeteran: true,
      militaryMonths: 0,
    });
    assert.equal(result.eligible, false);
    assert.match(result.primaryReason, /연령/);
  });

  test("1985.6.30 + isVeteran true + 6개월 → eligible (1년 미만 = +1, 1985.1.1 통과)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      birthDate: "1985-06-30",
      isVeteran: true,
      militaryMonths: 6,
    });
    assert.equal(result.eligible, true);
  });

  test("1985.6.30 + isVeteran true + 18개월 → eligible (+2, 1984.1.1 통과)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      birthDate: "1985-06-30",
      isVeteran: true,
      militaryMonths: 18,
    });
    assert.equal(result.eligible, true);
  });

  test("1984.6.30 + isVeteran true + 18개월 → eligible (+2)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      birthDate: "1984-06-30",
      isVeteran: true,
      militaryMonths: 18,
    });
    assert.equal(result.eligible, true);
  });

  test("1983.6.30 + isVeteran true + 30개월 → eligible (+3)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      birthDate: "1983-06-30",
      isVeteran: true,
      militaryMonths: 30,
    });
    assert.equal(result.eligible, true);
  });

  test("1982.6.30 + isVeteran true + 30개월 → FAIL (+3 한도 = 1983.1.1 이후만 가능)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      birthDate: "1982-06-30",
      isVeteran: true,
      militaryMonths: 30,
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
    assert.equal(result.eligible, true);
    assert.equal(result.tier.rank, 4);
  });

  test("보증금 8000만 + 월세 70만 → 환산식 실패 (100만 > 90만)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      depositWon: 80_000_000,
      monthlyRentWon: 700_000,
    });
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("월세")));
  });
});

// =================================================================
// 소득 (절대값 비교)
// =================================================================

describe("소득 (절대값)", () => {
  test("1인 + 월 1,230,834원 (정확히 48%) → FAIL (48% 초과여야 함)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      monthlyIncomeWon: 1_230_834,
    });
    assert.equal(result.eligible, false);
    assert.ok(
      result.allReasons.some((r) => r.includes("48%") || r.includes("주거급여")),
      `expected 48% reason, got ${JSON.stringify(result.allReasons)}`
    );
    assert.ok(
      result.alternativeProgramSuggestions.some((s) => s.includes("주거급여")),
      `expected 주거급여 alt, got ${JSON.stringify(result.alternativeProgramSuggestions)}`
    );
  });

  test("1인 + 월 1,230,835원 (48% + 1원) → eligible 가능 (48% 초과)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      monthlyIncomeWon: 1_230_835,
    });
    assert.equal(result.eligible, true);
  });

  test("1인 + 월 3,846,357원 (정확히 150%) → eligible (150% 이하)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      depositWon: 80_000_000,
      monthlyRentWon: 600_000,
      monthlyIncomeWon: 3_846_357,
    });
    assert.equal(result.eligible, true);
  });

  test("1인 + 월 3,846,358원 (150% + 1원) → FAIL", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      monthlyIncomeWon: 3_846_358,
    });
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("150%")));
  });

  test("4인 + 월 9,742,107원 (정확히 4인 150%) → eligible", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      householdSize: 4,
      monthlyIncomeWon: 9_742_107,
    });
    assert.equal(result.eligible, true);
  });

  test("1인 + 월 100만원 (48% 미만) → FAIL + 주거급여 추천", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      monthlyIncomeWon: 1_000_000,
    });
    assert.equal(result.eligible, false);
    assert.ok(
      result.alternativeProgramSuggestions.some((s) => s.includes("주거급여")),
      `expected 주거급여 alt, got ${JSON.stringify(result.alternativeProgramSuggestions)}`
    );
  });
});

// =================================================================
// 재산 (일반재산 합계 + 차량)
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

  test("일반재산 정확히 1.3억 → eligible (이하)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      generalAssetWon: 130_000_000,
    });
    assert.equal(result.eligible, true);
  });

  test("일반재산 1.3억 + 1원 → FAIL", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      generalAssetWon: 130_000_001,
    });
    assert.equal(result.eligible, false);
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
      monthlyIncomeWon: 3_680_000, // 2인 약 87.6%
      spouseBirthDate: "1995-06-15",
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
// 신혼부부 배우자 청년 연령
// =================================================================

describe("신혼부부 배우자 연령", () => {
  test("본인 1990 + 배우자 1980 → FAIL (배우자 연령 초과)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      householdType: "young-newlywed",
      hasNewlywedChildren: false,
      householdSize: 2,
      monthlyIncomeWon: 3_680_000,
      birthDate: "1990-06-15",
      spouseBirthDate: "1980-06-15",
      spouseIsVeteran: false,
      spouseMilitaryMonths: 0,
    });
    assert.equal(result.eligible, false);
    assert.ok(
      result.allReasons.some((r) => r.includes("배우자") && r.includes("연령")),
      `expected 배우자 연령 reason, got ${JSON.stringify(result.allReasons)}`
    );
  });

  test("본인 1990 + 배우자 1992 → 자격 OK", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      householdType: "young-newlywed",
      hasNewlywedChildren: false,
      householdSize: 2,
      monthlyIncomeWon: 3_680_000,
      birthDate: "1990-06-15",
      spouseBirthDate: "1992-06-15",
    });
    assert.equal(result.eligible, true);
  });
});

// =================================================================
// Exclusions
// =================================================================

describe("Exclusions", () => {
  test("임대인 = 배우자 → FAIL", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      landlordRelation: "spouse",
    });
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("배우자") || r.includes("부모")));
  });

  test("임대인 = 부모 → FAIL", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      landlordRelation: "parent",
    });
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("부모") || r.includes("배우자")));
  });

  test("임대인 = other → eligible 가능", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      landlordRelation: "other",
    });
    assert.equal(result.eligible, true);
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

  test("자치구 청년월세지원 수혜 중 → FAIL", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      receivingDistrictRent: true,
    });
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("자치구")));
  });

  test("서울시 청년수당 수혜 중 → FAIL", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      receivingSeoulYouthAllowance: true,
    });
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("청년수당")));
  });

  test("자립준비청년 월세·기숙사비 지원 수혜 중 → FAIL", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      receivingTransitionYouthSupport: true,
    });
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("자립준비")));
  });

  test("일반 공공임대 거주 → FAIL", () => {
    const input = { ...BASE_OK_INPUT, inPublicHousing: true };
    const result = evaluateSeoulYouthRent2026(input);
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("공공임대")));
  });

  test("신혼부부 양측 신청 → FAIL", () => {
    const input = {
      ...BASE_OK_INPUT,
      householdType: "young-newlywed",
      spouseBirthDate: "1990-01-01",
      spouseIsVeteran: false,
      spouseMilitaryMonths: 0,
      spouseNationalityStatus: "korean",
      hasNewlywedChildren: false,
      bothNewlywedsApplying: true,
    };
    const result = evaluateSeoulYouthRent2026(input);
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("신혼부부") || r.includes("부부 중")));
  });

  test("기타 유사 사업 동시 수혜 → FAIL", () => {
    const input = { ...BASE_OK_INPUT, receivingOtherSimilarProgram: true };
    const result = evaluateSeoulYouthRent2026(input);
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("유사")));
  });
});

// =================================================================
// 외국인 / 재외국민
// =================================================================

describe("외국인 / 재외국민", () => {
  test("nationalityStatus: 'foreigner' (단독 신청) → FAIL", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      nationalityStatus: "foreigner",
    });
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("외국인") || r.includes("재외국민")));
  });

  test("1인 + nationalityStatus: 'overseas-korean' → FAIL", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      nationalityStatus: "overseas-korean",
    });
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("외국인") || r.includes("재외국민")));
  });

  test("신혼 + 본인 korean + 배우자 foreigner + 가족관계 X → FAIL (요건 미충족)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      householdType: "young-newlywed",
      hasNewlywedChildren: false,
      householdSize: 2,
      monthlyIncomeWon: 3_680_000,
      spouseBirthDate: "1995-06-15",
      nationalityStatus: "korean",
      spouseNationalityStatus: "foreigner",
      spouseInFamilyRegistry: false,
      spouseSameAddress: true,
    });
    assert.equal(result.eligible, false);
    assert.ok(
      result.allReasons.some((r) => r.includes("가족관계") || r.includes("주소지")),
      `expected 가족관계/주소지 reason, got ${JSON.stringify(result.allReasons)}`
    );
  });

  test("신혼 + 본인 korean + 배우자 foreigner + 가족관계 O + 주소지 O → eligible", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      householdType: "young-newlywed",
      hasNewlywedChildren: false,
      householdSize: 2,
      monthlyIncomeWon: 3_680_000,
      spouseBirthDate: "1995-06-15",
      nationalityStatus: "korean",
      spouseNationalityStatus: "foreigner",
      spouseInFamilyRegistry: true,
      spouseSameAddress: true,
    });
    assert.equal(result.eligible, true);
  });
});

// =================================================================
// 거주지
// =================================================================

describe("거주지", () => {
  test("부산 거주 → FAIL + 정부24 안내", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      residence: "부산",
    });
    assert.equal(result.eligible, false);
    assert.ok(result.allReasons.some((r) => r.includes("서울")));
    assert.ok(
      result.alternativeProgramSuggestions.some((s) => s.includes("정부24")),
      `expected 정부24 안내, got ${JSON.stringify(result.alternativeProgramSuggestions)}`
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

  test("자격 OK + 군복무 보정 적용 (isVeteran true + 24개월) → 병적증명서 추가", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      isVeteran: true,
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
// 주택바우처 (monthlyBenefitNote)
// =================================================================

describe("주택바우처 (monthlyBenefitNote)", () => {
  test("자격 OK + 주택바우처 X → 기본 안내", () => {
    const result = evaluateSeoulYouthRent2026(BASE_OK_INPUT);
    assert.equal(result.eligible, true);
    assert.match(result.monthlyBenefitNote, /월 최대 20만원/);
    assert.ok(!result.monthlyBenefitNote.includes("차액"));
  });

  test("자격 OK + 주택바우처 O → 차액 지급 안내", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      receivingSeoulHousingVoucher: true,
    });
    assert.equal(result.eligible, true);
    assert.match(result.monthlyBenefitNote, /차액/);
  });
});

// =================================================================
// Tier 매칭
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

  test("Tier 1 경계 — 보증금 500만 + 월세 40만 + 소득 정확히 120% → rank 1", () => {
    // 1인 120% = 3,077,086원
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      depositWon: 5_000_000,
      monthlyRentWon: 400_000,
      monthlyIncomeWon: 3_077_086,
    });
    assert.equal(result.eligible, true);
    assert.equal(result.tier.rank, 1);
  });

  test("Tier 2 경계 — 소득 120% + 1원 → rank 2 (1구간 120% 초과)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      depositWon: 5_000_000,
      monthlyRentWon: 400_000,
      monthlyIncomeWon: 3_077_087,
    });
    assert.equal(result.eligible, true);
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
// 가구원수별 중위소득 계산 검증 (UI 표시용 percent)
// =================================================================

describe("중위소득 계산 (UI %)", () => {
  test("2인가구 + 월 4,199,292원 → 100% (2026 새 분모)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      householdSize: 2,
      monthlyIncomeWon: 4_199_292,
    });
    assert.equal(result.incomePercent, 100);
  });

  test("4인가구 + 월 6,494,738원 → 100% (2026 새 분모)", () => {
    const result = evaluateSeoulYouthRent2026({
      ...BASE_OK_INPUT,
      householdSize: 4,
      monthlyIncomeWon: 6_494_738,
    });
    assert.equal(result.incomePercent, 100);
  });
});

// =================================================================
// Tier union 타입 (1인 = rank/ratio, 그 외 = category-pool)
// =================================================================

describe("Tier union 타입", () => {
  test("1인 가구 자격 OK → tier rank/ratio 형태", () => {
    const result = evaluateSeoulYouthRent2026(BASE_OK_INPUT);
    assert.equal(result.eligible, true);
    assert.ok(result.tier);
    assert.ok("rank" in result.tier, "1인은 rank 필드");
    assert.ok(typeof result.tier.ratio === "number");
  });

  test("신혼부부 자격 OK → tier category-pool 형태", () => {
    const input = {
      ...BASE_OK_INPUT,
      householdType: "young-newlywed",
      spouseBirthDate: "1990-01-01",
      spouseIsVeteran: false,
      spouseMilitaryMonths: 0,
      spouseNationalityStatus: "korean",
      hasNewlywedChildren: false,
      bothNewlywedsApplying: false,
    };
    const result = evaluateSeoulYouthRent2026(input);
    assert.equal(result.eligible, true);
    assert.ok(result.tier);
    assert.equal(result.tier.type, "category-pool");
    assert.ok(result.tier.householdLabel.includes("신혼부부"));
  });

  test("청년안심주택 민간 → tier category-pool", () => {
    const input = {
      ...BASE_OK_INPUT,
      householdType: "youth-safe-housing",
      youthSafeHousingType: "private",
    };
    const result = evaluateSeoulYouthRent2026(input);
    assert.equal(result.eligible, true);
    assert.equal(result.tier.type, "category-pool");
  });
});

// =================================================================
// PDF 직접 예시 boundary
// =================================================================

describe("PDF 예시 boundary", () => {
  test("PDF 예시1 — 보증금 2천만 + 월세 80만 → eligible (환산 87.5만)", () => {
    const input = { ...BASE_OK_INPUT, depositWon: 20_000_000, monthlyRentWon: 800_000 };
    const result = evaluateSeoulYouthRent2026(input);
    assert.equal(result.eligible, true);
  });

  test("PDF 예시2 — 보증금 4천만 + 월세 80만 → FAIL (환산 95만)", () => {
    const input = { ...BASE_OK_INPUT, depositWon: 40_000_000, monthlyRentWon: 800_000 };
    const result = evaluateSeoulYouthRent2026(input);
    assert.equal(result.eligible, false);
  });
});
