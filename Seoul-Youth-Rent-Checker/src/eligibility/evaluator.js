/**
 * 2026 서울시 청년월세지원 자격 평가 엔진.
 *
 * 평가는 deterministic. JSON 데이터(`programs/seoul-youth-rent-2026.json`)를
 * 단일 진실 원천(SSOT)으로 사용한다 — 매직 넘버 사용 금지.
 *
 * 출력은 사용자에게 그대로 노출 가능한 한국어 사유와
 * UI에서 분기 처리할 수 있는 구조화 필드를 함께 반환한다.
 */

import program from "../../programs/seoul-youth-rent-2026.json" with { type: "json" };
import {
  calculateMedianIncomePercent,
  evaluateIncomeRange,
  meetsRentLimit,
  calculateAgeWithMilitary,
  matchTier,
} from "./utils.js";

/**
 * @typedef {object} EligibilityInput
 * @property {string} birthDate - "1995-06-15"
 * @property {boolean} isVeteran - 의무복무 마친 제대군인 여부
 * @property {number} militaryMonths - 0~36+
 * @property {string} residence - "서울" | "경기" | etc.
 * @property {"single"|"single-parent"|"fraud-victim"|"young-newlywed"|"youth-safe-housing"} householdType
 * @property {boolean} hasNewlywedChildren - 신혼만 사용 (true면 FAIL)
 * @property {boolean} hasSinglParentCert - 한부모만 사용
 * @property {boolean} hasFraudVictimCert - 전세사기만 사용
 * @property {"public"|"private"|null} youthSafeHousingType - 청년안심주택만
 * @property {number} householdSize - 가구원 수
 * @property {number} monthlyIncomeWon - 가구 월소득 (세전)
 * @property {number} depositWon
 * @property {number} monthlyRentWon
 * @property {number} generalAssetWon - 일반재산 (임차보증금+차량 등 합계)
 * @property {number} vehicleValueWon
 * @property {boolean} ownsHome
 * @property {"spouse"|"parent"|"other"|"none"} landlordRelation - 임대인 관계
 * @property {boolean} allCotenantsApplying
 * @property {boolean} receivingNationalYouthRent - 국토부 한시지원 수혜 중
 * @property {boolean} previouslyReceivedSeoulRent - 서울시 기수령
 * @property {boolean} basicLivingRecipient - 국기초 수급자
 * @property {"korean"|"foreigner"|"overseas-korean"} nationalityStatus - 본인 국적 상태
 * @property {"korean"|"foreigner"|"overseas-korean"} [spouseNationalityStatus] - 신혼부부 배우자 국적
 * @property {boolean} [spouseInFamilyRegistry] - 신혼+배우자 외국인일 때 가족관계 등재 여부
 * @property {boolean} [spouseSameAddress] - 신혼+배우자 외국인일 때 주소지 동일 여부
 * @property {string} [spouseBirthDate] - 신혼부부 배우자 출생일
 * @property {boolean} [spouseIsVeteran] - 신혼부부 배우자 제대군인 여부
 * @property {number} [spouseMilitaryMonths] - 신혼부부 배우자 복무 개월
 * @property {boolean} receivingDistrictRent - 자치구 청년월세 수혜 중
 * @property {boolean} receivingSeoulYouthAllowance - 서울시 청년수당 수혜 중
 * @property {boolean} receivingTransitionYouthSupport - 자립준비청년 월세·기숙사비 지원 수혜 중
 * @property {boolean} receivingSeoulHousingVoucher - 서울형 주택바우처 수급자
 * @property {boolean} inPublicHousing - 일반 공공임대 거주 (영구임대/공공임대/국민임대/매입임대/행복주택/장기안심/특화형/도시형생활/희망하우징/전세임대/공무원 등). 청년안심주택은 householdType "youth-safe-housing"으로 따로.
 * @property {boolean} bothNewlywedsApplying - 신혼부부 양측 신청 (신혼만 의미)
 * @property {boolean} receivingOtherSimilarProgram - 기타 유사 사업 동시 수혜 (자치구/청년수당/자립준비/주택바우처 외)
 */

/**
 * @typedef {object} EligibilityResult
 * @property {boolean} eligible
 * @property {string|null} primaryReason
 * @property {string[]} allReasons
 * @property {number|null} incomePercent
 * @property {{rank: 1|2|3|4, ratio: number} | {type: "category-pool", label: string, householdLabel: string} | null} tier
 * @property {string[]} requiredDocuments
 * @property {string[]} alternativeProgramSuggestions
 * @property {string} monthlyBenefitNote - 자격 OK 시 월 지급액 안내 (주택바우처 차감 여부 반영)
 */

const ELIG = program.eligibility;
const ALT = program.alternativePrograms;

/**
 * 출생일이 [oldestAllowed, youngestAllowed] 범위 안에 있는지 확인.
 *
 * @param {string} birthDateStr
 * @param {string} oldestAllowedStr - "YYYY-MM-DD"
 * @param {string} youngestAllowedStr - "YYYY-MM-DD"
 * @returns {{ok: boolean, tooOld: boolean, tooYoung: boolean}}
 */
function checkBirthDateInRange(birthDateStr, oldestAllowedStr, youngestAllowedStr) {
  const birth = new Date(birthDateStr);
  const oldest = new Date(oldestAllowedStr);
  const youngest = new Date(youngestAllowedStr);
  const tooOld = birth < oldest;
  const tooYoung = birth > youngest;
  return { ok: !tooOld && !tooYoung, tooOld, tooYoung };
}

/**
 * 자격 X 사유에 맞는 alternative 추천을 만들어 반환.
 *
 * @param {string[]} reasons
 * @param {boolean} isResidenceFail
 * @param {boolean} isAgeOutFail
 * @param {boolean} isIncomeBelowFail
 * @returns {string[]}
 */
function buildAlternativeSuggestions({ isResidenceFail, isAgeOutFail, isIncomeBelowFail }) {
  /** @type {string[]} */
  const suggestions = [];

  if (isIncomeBelowFail) {
    // 중위소득 48% 이하
    suggestions.push("주거급여 (보건복지부) — 동주민센터 신청");
    suggestions.push("서울형 주택바우처 — 동주민센터 신청");
    suggestions.push("국토부 청년월세 한시 특별지원 (만 19~34세, 중위 60% 이하)");
  } else if (isAgeOutFail) {
    // 연령 미달/초과
    suggestions.push(`${ALT.ageOutOfRange.label} (만 19~34세) — ${ALT.ageOutOfRange.description}`);
  } else if (isResidenceFail) {
    suggestions.push("정부24 청년월세 정책 검색 (지자체별)");
  }

  return suggestions;
}

/**
 * householdType → tier 미적용(유형별 추첨) 라벨 매핑.
 *
 * @param {EligibilityInput["householdType"]} householdType
 * @returns {string}
 */
function getHouseholdLabel(householdType) {
  switch (householdType) {
    case "single-parent":
      return "한부모가족 추첨";
    case "fraud-victim":
      return "전세사기피해자 추첨";
    case "young-newlywed":
      return "청년 신혼부부 추첨";
    case "youth-safe-housing":
      return "청년안심주택(민간) 추첨";
    default:
      return "유형별 추첨";
  }
}

/**
 * @param {EligibilityInput} input
 * @returns {EligibilityResult}
 */
export function evaluateSeoulYouthRent2026(input) {
  /** @type {string[]} */
  const reasons = [];

  let isResidenceFail = false;
  let isAgeOutFail = false;
  let isIncomeBelowFail = false;

  // --- 1. 거주지 (서울만) ---
  const allowedRegions = ELIG.residence.allowed;
  const isSeoul = allowedRegions.includes(input.residence);
  if (!isSeoul) {
    reasons.push("서울 거주자만 신청 가능해요.");
    isResidenceFail = true;
  }

  // --- 2. 외국인 / 재외국민 (앞으로 이동 — 다른 정보 입력해도 의미 X) ---
  // 본인이 외국인/재외국민이면 기본 FAIL.
  // 단, 신혼부부 + 본인 한국인 + 배우자 외국인 + 가족관계 등재 + 주소지 동일 → 예외 OK.
  const householdType = input.householdType;
  if (input.nationalityStatus !== "korean") {
    reasons.push("외국인 또는 재외국민은 신청할 수 없어요. (본인 한국인 + 신혼 배우자만 가족관계/주소지 충족 시 외국인 가능)");
  }
  if (
    householdType === "young-newlywed" &&
    input.nationalityStatus === "korean" &&
    input.spouseNationalityStatus &&
    input.spouseNationalityStatus !== "korean"
  ) {
    // 배우자 외국인이면 예외 조건 검사
    const inRegistry = input.spouseInFamilyRegistry === true;
    const sameAddress = input.spouseSameAddress === true;
    if (!inRegistry || !sameAddress) {
      reasons.push("배우자가 외국인/재외국민인 경우, 가족관계 등재 + 주소지 동일 요건을 모두 충족해야 해요.");
    }
  }

  // --- 3. 무주택 ---
  if (input.ownsHome) {
    reasons.push("주택을 소유 중이라 신청할 수 없어요. (오피스텔/분양권/공유지분 포함)");
  }

  // --- 4. 연령 (군복무 +최대 3년 계단식 보정) ---
  const ageInfo = calculateAgeWithMilitary(
    input.birthDate,
    input.isVeteran ?? false,
    input.militaryMonths ?? 0
  );
  const ageRange = checkBirthDateInRange(
    input.birthDate,
    ageInfo.oldestAllowedBirthDate,
    ageInfo.youngestAllowedBirthDate
  );

  if (ageRange.tooOld) {
    reasons.push("연령 기준을 초과했어요. (군복무 최대 3년 연장 적용해도 만 39세 초과)");
    isAgeOutFail = true;
  } else if (ageRange.tooYoung) {
    reasons.push("아직 만 19세가 되지 않아 신청할 수 없어요.");
    isAgeOutFail = true;
  }

  // --- 5. 가구형태별 분기 ---
  if (householdType === "young-newlywed" && input.hasNewlywedChildren) {
    reasons.push("청년신혼부부는 무자녀 조건이라, 자녀가 있으면 신청할 수 없어요.");
  }
  if (householdType === "single-parent" && !input.hasSinglParentCert) {
    reasons.push("한부모 가구로 신청하려면 한부모가족증명서가 필요해요.");
  }
  if (householdType === "fraud-victim" && !input.hasFraudVictimCert) {
    reasons.push("전세사기 피해자로 신청하려면 결정문 사본이 필요해요.");
  }
  if (householdType === "youth-safe-housing" && input.youthSafeHousingType === "public") {
    reasons.push("청년안심주택 공공임대 거주자는 신청할 수 없어요. (민간임대만 가능)");
  }

  // --- 5-2. 신혼부부 배우자 청년 연령 충족 ---
  if (householdType === "young-newlywed" && input.spouseBirthDate) {
    const spouseAgeInfo = calculateAgeWithMilitary(
      input.spouseBirthDate,
      input.spouseIsVeteran ?? false,
      input.spouseMilitaryMonths ?? 0
    );
    const spouseRange = checkBirthDateInRange(
      input.spouseBirthDate,
      spouseAgeInfo.oldestAllowedBirthDate,
      spouseAgeInfo.youngestAllowedBirthDate
    );
    if (spouseRange.tooOld) {
      reasons.push("신혼부부 배우자도 청년 연령(만 19~39세, 군복무 보정 포함)을 충족해야 해요. 배우자 연령 초과.");
      isAgeOutFail = true;
    } else if (spouseRange.tooYoung) {
      reasons.push("신혼부부 배우자도 만 19세 이상이어야 해요.");
      isAgeOutFail = true;
    }
  }

  // --- 5-3. 신혼부부 부부 모두 신청 (PDF 제외사유 #14) ---
  if (householdType === "young-newlywed" && input.bothNewlywedsApplying) {
    reasons.push("신혼부부는 부부 중 1명만 신청할 수 있어요.");
  }

  // --- 6. 보증금 8천만원 이하 ---
  if (input.depositWon > ELIG.deposit.max) {
    reasons.push("임차보증금이 8,000만원을 초과해서 신청할 수 없어요.");
  }

  // --- 7. 월세 60 이하 OR 환산식 통과 ---
  const rentOk = meetsRentLimit(input.depositWon, input.monthlyRentWon);
  if (!rentOk) {
    reasons.push("월세 한도(60만원 이하 또는 보증금 환산 후 90만원 이하)를 초과했어요.");
  }

  // --- 8. 중위소득 48 초과 ~ 150 이하 (절대값) ---
  const incomeRange = evaluateIncomeRange(input.householdSize, input.monthlyIncomeWon);
  const incomePercent = calculateMedianIncomePercent(input.householdSize, input.monthlyIncomeWon);

  if (incomeRange.bucket === "below48") {
    reasons.push("기준중위소득 48% 이하예요. 주거급여(국기초)/주택바우처가 더 적합할 수 있어요.");
    isIncomeBelowFail = true;
  } else if (incomeRange.bucket === "above150") {
    reasons.push("기준중위소득 150%를 초과해서 신청할 수 없어요.");
  }

  // --- 9. 일반재산(임차보증금+차량 등 합계) 1.3억 이하 ---
  if (input.generalAssetWon > ELIG.asset.generalMax) {
    reasons.push("일반재산(임차보증금+차량 등 합계)이 1.3억원을 초과해서 신청할 수 없어요.");
  }

  // --- 10. 차량 시가 2,500만 미만 ---
  if (input.vehicleValueWon >= ELIG.asset.vehicleMax) {
    reasons.push("차량 시가표준액이 2,500만원 이상이라 신청할 수 없어요.");
  }

  // --- 11. 임대인 = 배우자 또는 부모 ---
  if (input.landlordRelation === "spouse" || input.landlordRelation === "parent") {
    reasons.push("임대인이 배우자 또는 부모인 경우 신청할 수 없어요.");
  }

  // --- 12. 공동임차인 모두 신청 ---
  if (input.allCotenantsApplying) {
    reasons.push("공동임차인 중 1명만 신청할 수 있어요.");
  }

  // --- 13. 국기초 수급 X ---
  if (input.basicLivingRecipient) {
    reasons.push("국민기초생활보장 수급 중에는 중복 수령이 안 돼요.");
  }

  // --- 14. 국토부 한시지원 수혜 중 X ---
  if (input.receivingNationalYouthRent) {
    reasons.push("국토부 청년월세 한시지원을 받는 중에는 중복 신청할 수 없어요.");
  }

  // --- 15. 서울시 기수령 X ---
  if (input.previouslyReceivedSeoulRent) {
    reasons.push("서울시 청년월세지원은 생애 1회라, 이미 받은 적이 있으면 신청할 수 없어요.");
  }

  // --- 16. 자치구 청년월세지원 수혜 중 ---
  if (input.receivingDistrictRent) {
    reasons.push("자치구 청년월세지원 수혜 중에는 중복 신청할 수 없어요.");
  }

  // --- 17. 서울시 청년수당 수혜 중 ---
  if (input.receivingSeoulYouthAllowance) {
    reasons.push("서울시 청년수당을 받는 중에는 중복 신청할 수 없어요.");
  }

  // --- 18. 자립준비청년 월세·기숙사비 지원 수혜 중 ---
  if (input.receivingTransitionYouthSupport) {
    reasons.push("자립준비청년 월세·기숙사비 지원을 받는 중에는 중복 신청할 수 없어요.");
  }

  // --- 19. 일반 공공임대 거주 (PDF 제외사유 #11) ---
  if (input.inPublicHousing) {
    reasons.push("공공임대주택 거주자는 신청할 수 없어요. (행복주택/영구임대/국민임대/매입임대 등 — 단 청년안심주택 민간은 OK)");
  }

  // --- 20. 기타 유사 사업 동시 수혜 (PDF 제외사유 #10) ---
  if (input.receivingOtherSimilarProgram) {
    reasons.push("다른 유사 청년 주거 지원 사업을 받고 있으면 신청할 수 없어요.");
  }

  // --- 결과 결정 ---
  if (reasons.length > 0) {
    return {
      eligible: false,
      primaryReason: reasons[0],
      allReasons: reasons,
      incomePercent,
      tier: null,
      requiredDocuments: [],
      alternativeProgramSuggestions: buildAlternativeSuggestions({
        isResidenceFail,
        isAgeOutFail,
        isIncomeBelowFail,
      }),
      monthlyBenefitNote: "",
    };
  }

  // --- 자격 OK → tier 매칭 (단, 1인 가구만) + 서류 ---
  // PDF: tier 4구간 매칭은 "청년 1인 가구" 한정.
  // 신혼/한부모/전세사기/청년안심주택은 유형별 추첨 (구간 X).
  let tier;
  if (householdType === "single") {
    const matched = matchTier(input.depositWon, input.monthlyRentWon, incomeRange);
    // tier가 null이면 이론상 자격은 통과했지만 매트릭스 어디에도 안 맞는 케이스
    // — 공고문상 사실상 발생 불가능하지만 안전장치로 4구간 fallback 처리
    // (deposit ≤ 8천 + rent OK + income 48~150% 통과했으니 4구간 매칭 보장됨)
    tier = matched ?? { rank: 4, ratio: program.selectionTiers[3].ratio };
  } else {
    tier = {
      type: "category-pool",
      label: "유형별 추첨 (구간 X)",
      householdLabel: getHouseholdLabel(householdType),
    };
  }

  return {
    eligible: true,
    primaryReason: null,
    allReasons: [],
    incomePercent,
    tier,
    requiredDocuments: buildRequiredDocuments(input),
    alternativeProgramSuggestions: [],
    monthlyBenefitNote: input.receivingSeoulHousingVoucher
      ? "월 최대 20만원 - 주택바우처 수령액 (차액만 지급)"
      : "월 최대 20만원 (월세금액 한도 내)",
  };
}

/**
 * 자격 OK 사용자에게 안내할 서류 목록 (label 문자열 배열).
 *
 * @param {EligibilityInput} input
 * @returns {string[]}
 */
function buildRequiredDocuments(input) {
  /** @type {string[]} */
  const docs = [];

  for (const doc of program.documents.required) {
    docs.push(doc.label);
  }

  // 가구형태별 추가 서류
  const byType = program.documents.byHouseholdType[input.householdType];
  if (byType) {
    for (const doc of byType) {
      docs.push(doc.label);
    }
  }

  // 군복무 보정 적용 시 (제대군인 + 1개월 이상) 병적증명서 필요
  // 본인 또는 배우자 (신혼) 어느 한쪽이라도 보정 필요하면 추가
  const selfNeedsRecord = (input.isVeteran ?? false) && (input.militaryMonths ?? 0) >= 1;
  const spouseNeedsRecord =
    input.householdType === "young-newlywed" &&
    (input.spouseIsVeteran ?? false) &&
    (input.spouseMilitaryMonths ?? 0) >= 1;

  if (selfNeedsRecord || spouseNeedsRecord) {
    for (const doc of program.documents.byCondition["military-extended"]) {
      docs.push(doc.label);
    }
  }

  return docs;
}
