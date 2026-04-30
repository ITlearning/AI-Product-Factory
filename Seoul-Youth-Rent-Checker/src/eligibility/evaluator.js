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
  meetsRentLimit,
  calculateAgeWithMilitary,
  matchTier,
} from "./utils.js";

/**
 * @typedef {object} EligibilityInput
 * @property {string} birthDate - "1995-06-15"
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
 * @property {number} generalAssetWon
 * @property {number} vehicleValueWon
 * @property {boolean} ownsHome
 * @property {boolean} landlordIsParent
 * @property {boolean} allCotenantsApplying
 * @property {boolean} receivingNationalYouthRent - 국토부 한시지원 수혜 중
 * @property {boolean} previouslyReceivedSeoulRent - 서울시 기수령
 * @property {boolean} basicLivingRecipient - 국기초 수급자
 */

/**
 * @typedef {object} EligibilityResult
 * @property {boolean} eligible
 * @property {string|null} primaryReason
 * @property {string[]} allReasons
 * @property {number|null} incomePercent
 * @property {{rank: number, ratio: number}|null} tier
 * @property {string[]} requiredDocuments
 * @property {string[]} alternativeProgramSuggestions
 */

const ELIG = program.eligibility;
const REFERENCE_DATE = ELIG.age.referenceDate;
const ALT = program.alternativePrograms;

/**
 * @param {EligibilityInput} input
 * @returns {EligibilityResult}
 */
export function evaluateSeoulYouthRent2026(input) {
  /** @type {string[]} */
  const reasons = [];
  /** @type {Set<string>} */
  const altSuggestions = new Set();

  // --- 1. 거주지 (서울만) ---
  const allowedRegions = ELIG.residence.allowed;
  const isSeoul = allowedRegions.includes(input.residence);
  if (!isSeoul) {
    reasons.push("서울 거주자만 신청 가능해요.");
    altSuggestions.add(`${ALT.outsideSeoul.label} — ${ALT.outsideSeoul.description}`);
  }

  // --- 2. 무주택 ---
  if (input.ownsHome) {
    reasons.push("주택을 소유 중이라 신청할 수 없어요. (오피스텔/분양권/공유지분 포함)");
  }

  // --- 3. 연령 (군복무 +최대 3년 적용) ---
  const ageEffective = calculateAgeWithMilitary(
    input.birthDate,
    input.militaryMonths ?? 0,
    REFERENCE_DATE
  );
  const birth = new Date(input.birthDate);
  const ageMin = new Date(ELIG.age.min); // 1986-01-01 (이 날 이후 출생자만)
  const ageMax = new Date(ELIG.age.max); // 2007-12-31 (이 날 이전 출생자만)

  // 군복무 개월을 출생일에 가산해 "보정 출생일"을 만든 뒤 범위 비교 (가장 정확)
  const militaryMonths = Math.min(36, Math.max(0, input.militaryMonths ?? 0));
  const adjustedBirth = new Date(birth);
  adjustedBirth.setMonth(adjustedBirth.getMonth() + militaryMonths);

  const ageTooOld = adjustedBirth < ageMin; // 보정 후에도 1986.1.1보다 이른 출생 → 너무 나이 많음
  const ageTooYoung = birth > ageMax; // 출생일이 2007.12.31보다 늦음 → 너무 어림

  if (ageTooOld) {
    reasons.push("연령 기준을 초과했어요. (군복무 최대 3년 연장 적용해도 만 39세 초과)");
    altSuggestions.add(`${ALT.ageOutOfRange.label} — ${ALT.ageOutOfRange.description}`);
  } else if (ageTooYoung) {
    reasons.push("아직 만 19세가 되지 않아 신청할 수 없어요.");
  }

  // --- 4. 가구형태별 분기 ---
  const householdType = input.householdType;
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

  // --- 5. 보증금 8천만원 이하 ---
  if (input.depositWon > ELIG.deposit.max) {
    reasons.push("임차보증금이 8,000만원을 초과해서 신청할 수 없어요.");
  }

  // --- 6. 월세 60 이하 OR 환산식 통과 ---
  const rentOk = meetsRentLimit(input.depositWon, input.monthlyRentWon);
  if (!rentOk) {
    reasons.push("월세 한도(60만원 이하 또는 보증금 환산 후 90만원 이하)를 초과했어요.");
  }

  // --- 7. 중위소득 48~150% ---
  const incomePercent = calculateMedianIncomePercent(input.householdSize, input.monthlyIncomeWon);
  if (incomePercent < ELIG.income.minPercent) {
    reasons.push("기준중위소득 48% 미만이에요. 주거급여(국기초)가 더 적합할 수 있어요.");
    altSuggestions.add(`${ALT.incomeBelowMin.label} — ${ALT.incomeBelowMin.description}`);
  } else if (incomePercent > ELIG.income.maxPercent) {
    reasons.push("기준중위소득 150%를 초과해서 신청할 수 없어요.");
  }

  // --- 8. 일반재산 1.3억 이하 ---
  if (input.generalAssetWon > ELIG.asset.generalMax) {
    reasons.push("일반재산이 1.3억원을 초과해서 신청할 수 없어요.");
  }

  // --- 9. 차량 시가 2,500만 미만 ---
  if (input.vehicleValueWon >= ELIG.asset.vehicleMax) {
    reasons.push("차량 시가표준액이 2,500만원 이상이라 신청할 수 없어요.");
  }

  // --- 10. 임대인이 부모 ---
  if (input.landlordIsParent) {
    reasons.push("임대인이 부모인 경우 신청할 수 없어요.");
  }

  // --- 11. 공동임차인 모두 신청 ---
  if (input.allCotenantsApplying) {
    reasons.push("공동임차인 중 1명만 신청할 수 있어요.");
  }

  // --- 12. 국기초 수급 X ---
  if (input.basicLivingRecipient) {
    reasons.push("국민기초생활보장 수급 중에는 중복 수령이 안 돼요.");
  }

  // --- 13. 국토부 한시지원 수혜 중 X ---
  if (input.receivingNationalYouthRent) {
    reasons.push("국토부 청년월세 한시지원을 받는 중에는 중복 신청할 수 없어요.");
  }

  // --- 14. 서울시 기수령 X ---
  if (input.previouslyReceivedSeoulRent) {
    reasons.push("서울시 청년월세지원은 생애 1회라, 이미 받은 적이 있으면 신청할 수 없어요.");
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
      alternativeProgramSuggestions: Array.from(altSuggestions),
    };
  }

  // --- 자격 OK → tier 매칭 + 서류 ---
  const tier = matchTier(input.depositWon, input.monthlyRentWon, incomePercent);

  // tier가 null이면 이론상 자격은 통과했지만 매트릭스 어디에도 안 맞는 케이스
  // — 공고문상 사실상 발생 불가능하지만 안전장치로 4구간 fallback 처리
  // (deposit ≤ 8천 + rent OK + income 48~150% 통과했으니 4구간 매칭 보장됨)
  return {
    eligible: true,
    primaryReason: null,
    allReasons: [],
    incomePercent,
    tier: tier ?? { rank: 4, ratio: program.selectionTiers[3].ratio },
    requiredDocuments: buildRequiredDocuments(input),
    alternativeProgramSuggestions: [],
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

  // 군복무 연장 적용 시 병적증명서
  if ((input.militaryMonths ?? 0) >= 12) {
    for (const doc of program.documents.byCondition["military-extended"]) {
      docs.push(doc.label);
    }
  }

  return docs;
}
