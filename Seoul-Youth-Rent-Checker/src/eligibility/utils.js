/**
 * 자격 평가 공통 유틸리티 (pure functions)
 *
 * 매직 넘버는 호출 측(evaluator)에서 JSON으로부터 주입받는다.
 * 단, 보편 상수(보증금 환산율, 월세 환산 cap 등)는 JSON과 1:1 매핑되도록
 * 기본값으로 fallback 시그니처를 제공한다 — 테스트 편의 + 실제 사용은 JSON 주입.
 */

import program from "../../programs/seoul-youth-rent-2026.json" with { type: "json" };

const MEDIAN_INCOME_2026 = program.medianIncome2026.byHouseholdSize;
const RENT_CONVERSION_RATE = program.eligibility.monthlyRent.conversionRate;
const RENT_MONTHLY_CAP_WON = program.eligibility.monthlyRent.conversionMonthlyCapWon;
const RENT_DIRECT_MAX_WON = program.eligibility.monthlyRent.max;
const SELECTION_TIERS = program.selectionTiers;

/**
 * 가구원 수와 월소득(원)을 받아 기준중위소득 대비 % 반환.
 * 6인 초과 시 1인 추가당 약 920,000원씩 가산 (참고치 — 보건복지부 고시 기준).
 *
 * @param {number} householdSize - 가구원 수 (1 이상의 정수)
 * @param {number} monthlyIncomeWon - 가구 월소득(세전, 원)
 * @returns {number} 중위소득 대비 % (소수점 1자리 반올림)
 */
export function calculateMedianIncomePercent(householdSize, monthlyIncomeWon) {
  if (!Number.isFinite(householdSize) || householdSize < 1) {
    throw new Error("householdSize must be a positive integer");
  }
  if (!Number.isFinite(monthlyIncomeWon) || monthlyIncomeWon < 0) {
    throw new Error("monthlyIncomeWon must be a non-negative number");
  }

  const sizeKey = Math.min(Math.floor(householdSize), 6).toString();
  let medianIncome = MEDIAN_INCOME_2026[sizeKey];

  // 6인 초과 시 1인당 약 920,000원 가산 (5→6 증가폭 = 6인 - 5인 차이를 사용)
  if (householdSize > 6) {
    const extraPerPerson = MEDIAN_INCOME_2026["6"] - MEDIAN_INCOME_2026["5"];
    medianIncome = MEDIAN_INCOME_2026["6"] + extraPerPerson * (Math.floor(householdSize) - 6);
  }

  const percent = (monthlyIncomeWon / medianIncome) * 100;
  return Math.round(percent * 10) / 10;
}

/**
 * 보증금을 월세 환산값(원)으로 변환.
 * 환산식: 보증금 × 4.5% / 12
 *
 * @param {number} depositWon - 보증금(원)
 * @returns {number} 월 환산금액(원, 소수 절사)
 */
export function convertDepositToMonthly(depositWon) {
  if (!Number.isFinite(depositWon) || depositWon < 0) {
    throw new Error("depositWon must be a non-negative number");
  }
  return Math.floor((depositWon * RENT_CONVERSION_RATE) / 12);
}

/**
 * 월세 한도 충족 여부.
 * - 월세 ≤ 60만원 → 통과
 * - 월세 > 60만원이면 (보증금 환산 + 월세) ≤ 90만원 → 통과
 *
 * @param {number} depositWon - 보증금(원)
 * @param {number} rentWon - 월세(원)
 * @returns {boolean}
 */
export function meetsRentLimit(depositWon, rentWon) {
  if (!Number.isFinite(rentWon) || rentWon < 0) return false;
  if (!Number.isFinite(depositWon) || depositWon < 0) return false;

  if (rentWon <= RENT_DIRECT_MAX_WON) return true;

  const converted = convertDepositToMonthly(depositWon) + rentWon;
  return converted <= RENT_MONTHLY_CAP_WON;
}

/**
 * 군복무 개월 수를 적용한 만 나이 계산.
 * - referenceDate 시점의 만 나이를 구한 뒤 (군복무 개월 ÷ 12, 최대 3년)을 빼준다.
 * - 군복무 12개월 → +1년, 24개월 → +2년, 36개월 이상 → +3년 (소수 버림).
 *
 * @param {string} birthDate - "YYYY-MM-DD"
 * @param {number} militaryMonths - 군복무 개월 수 (0 이상)
 * @param {string} [referenceDate="2026-01-01"] - 기준 일자
 * @returns {number} 적용 만 나이 (양의 정수, 음수면 0)
 */
export function calculateAgeWithMilitary(birthDate, militaryMonths = 0, referenceDate = "2026-01-01") {
  const birth = new Date(birthDate);
  const ref = new Date(referenceDate);
  if (Number.isNaN(birth.getTime()) || Number.isNaN(ref.getTime())) {
    throw new Error("Invalid date");
  }

  let age = ref.getFullYear() - birth.getFullYear();
  const monthDiff = ref.getMonth() - birth.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && ref.getDate() < birth.getDate())) {
    age -= 1;
  }

  const months = Number.isFinite(militaryMonths) && militaryMonths > 0 ? militaryMonths : 0;
  const extensionYears = Math.min(3, Math.floor(months / 12));
  return Math.max(0, age - extensionYears);
}

/**
 * 보증금/월세/소득% 조건으로 4개 tier 중 어느 구간에 매칭되는지 결정.
 * - 1구간부터 순서대로 시도, 가장 좋은(낮은 rank = 높은 ratio) 구간 반환.
 * - 어느 구간에도 매칭 안 되면 null.
 *
 * 매칭 로직 (각 tier):
 *   deposit ≤ tier.deposit.max
 *   AND (rent ≤ tier.rent.max OR meetsRentLimit으로 해당 tier 환산 통과)
 *   AND incomePercent ∈ [tier.incomeRange.min, tier.incomeRange.max]
 *
 * 단, 4구간은 환산식이 적용 가능한 유일한 구간 (월세 60만 초과 + 환산 90만 이하).
 * 1~3구간은 직접 한도(rent.max) 안에서만 매칭 — 공고문 매트릭스 정확 반영.
 *
 * @param {number} depositWon
 * @param {number} rentWon
 * @param {number} incomePercent - 중위소득 대비 %
 * @returns {{rank: 1|2|3|4, ratio: number} | null}
 */
export function matchTier(depositWon, rentWon, incomePercent) {
  for (const tier of SELECTION_TIERS) {
    const depositOk = depositWon <= tier.deposit.max;
    const incomeOk = incomePercent >= tier.incomeRange.min && incomePercent <= tier.incomeRange.max;

    let rentOk;
    if (tier.rank === 4) {
      // 4구간만 환산식 허용 (월세 직접 한도 OR 환산 통과)
      rentOk = meetsRentLimit(depositWon, rentWon);
    } else {
      rentOk = rentWon <= tier.rent.max;
    }

    if (depositOk && rentOk && incomeOk) {
      return { rank: tier.rank, ratio: tier.ratio };
    }
  }
  return null;
}
