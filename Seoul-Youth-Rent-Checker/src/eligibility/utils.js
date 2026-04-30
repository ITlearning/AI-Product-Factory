/**
 * 자격 평가 공통 유틸리티 (pure functions)
 *
 * 매직 넘버는 호출 측(evaluator)에서 JSON으로부터 주입받는다.
 * 단, 보편 상수(보증금 환산율, 월세 환산 cap 등)는 JSON과 1:1 매핑되도록
 * 기본값으로 fallback 시그니처를 제공한다 — 테스트 편의 + 실제 사용은 JSON 주입.
 */

import program from "../../programs/seoul-youth-rent-2026.json" with { type: "json" };

const MEDIAN_INCOME_THRESHOLDS_2026 = program.medianIncomeThresholds2026.byHouseholdSize;
const MEDIAN_INCOME_INCREMENT_AFTER_7 = program.medianIncomeThresholds2026.incrementPerPersonAfter7;
const RENT_CONVERSION_RATE = program.eligibility.monthlyRent.conversionRate;
const RENT_MONTHLY_CAP_WON = program.eligibility.monthlyRent.conversionMonthlyCapWon;
const RENT_DIRECT_MAX_WON = program.eligibility.monthlyRent.max;
const SELECTION_TIERS = program.selectionTiers;
const AGE_MIN_BIRTH_DATE = program.eligibility.age.min; // "1986-01-01"
const AGE_MAX_BIRTH_DATE = program.eligibility.age.max; // "2007-12-31"
const INCOME_MIN_PCT = program.eligibility.income.minPercent;
const INCOME_MAX_PCT = program.eligibility.income.maxPercent;
const INCOME_TIER1_MAX_PCT = program.eligibility.income.tier1MaxPercent;

/**
 * 가구원 수와 월소득(원)을 받아 기준중위소득 대비 % 반환 (UI 표시용).
 * 분모는 게이트 평가와 동일한 MEDIAN_INCOME_THRESHOLDS_2026.pct100 사용.
 * 8인 이상은 7인 pct100 + (n-7) × 959,198원 (medianIncomeIncrementPerPersonAfter7).
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

  const size = Math.floor(householdSize);
  let medianIncome;
  if (size <= 7) {
    medianIncome = MEDIAN_INCOME_THRESHOLDS_2026[size.toString()].pct100;
  } else {
    // 8인 이상: 7인 100% + (n-7) × 959,198
    medianIncome =
      MEDIAN_INCOME_THRESHOLDS_2026["7"].pct100 + MEDIAN_INCOME_INCREMENT_AFTER_7 * (size - 7);
  }

  const percent = (monthlyIncomeWon / medianIncome) * 100;
  return Math.round(percent * 10) / 10;
}

/**
 * 가구원 수에 해당하는 절대값 thresholds 반환.
 * 7인까지는 JSON 직접 사용, 8인 이상은 7인값 + (n-7) × 959,198원을 base로 % 비례.
 *
 * @param {number} householdSize
 * @returns {{pct48: number, pct100: number, pct120: number, pct150: number}}
 */
function getIncomeThresholds(householdSize) {
  if (!Number.isFinite(householdSize) || householdSize < 1) {
    throw new Error("householdSize must be a positive integer");
  }

  const size = Math.floor(householdSize);
  if (size <= 7) {
    return MEDIAN_INCOME_THRESHOLDS_2026[size.toString()];
  }

  // 8인 이상: 7인 100% + (n-7) × 959,198 = base 100%
  const base100 = MEDIAN_INCOME_THRESHOLDS_2026["7"].pct100 + MEDIAN_INCOME_INCREMENT_AFTER_7 * (size - 7);
  return {
    pct48: Math.round((base100 * 48) / 100),
    pct100: base100,
    pct120: Math.round((base100 * 120) / 100),
    pct150: Math.round((base100 * 150) / 100),
  };
}

/**
 * 절대값 비교로 소득 범위 판단.
 * - within48to150: 월소득 > 48% threshold AND 월소득 ≤ 150% threshold
 * - within48to120: 월소득 > 48% threshold AND 월소득 ≤ 120% threshold (1구간 자격)
 * - bucket: 'below48' | 'tier1-3' | 'tier4-only' | 'above150'
 *   - below48: 월소득 ≤ 48% (FAIL — 주거급여 안내)
 *   - tier1-3: 48% 초과 ~ 120% 이하 (1~4 모든 구간 가능)
 *   - tier4-only: 120% 초과 ~ 150% 이하 (1구간 제외, 2~4구간만)
 *   - above150: 150% 초과 (FAIL)
 *
 * @param {number} householdSize
 * @param {number} monthlyIncomeWon
 * @returns {{within48to150: boolean, within48to120: boolean, bucket: 'below48'|'tier1-3'|'tier4-only'|'above150', thresholds: {pct48:number, pct100:number, pct120:number, pct150:number}}}
 */
export function evaluateIncomeRange(householdSize, monthlyIncomeWon) {
  if (!Number.isFinite(monthlyIncomeWon) || monthlyIncomeWon < 0) {
    throw new Error("monthlyIncomeWon must be a non-negative number");
  }

  const thresholds = getIncomeThresholds(householdSize);

  const above48 = monthlyIncomeWon > thresholds.pct48;
  const within120 = monthlyIncomeWon <= thresholds.pct120;
  const within150 = monthlyIncomeWon <= thresholds.pct150;

  let bucket;
  if (!above48) {
    bucket = "below48";
  } else if (within120) {
    bucket = "tier1-3";
  } else if (within150) {
    bucket = "tier4-only";
  } else {
    bucket = "above150";
  }

  return {
    within48to150: above48 && within150,
    within48to120: above48 && within120,
    bucket,
    thresholds,
  };
}

/**
 * 보증금을 월세 환산값(원)으로 변환.
 * 환산식: 보증금 × 4.5% / 12, **천원 단위 절사** (PDF 명시).
 *
 * @param {number} depositWon - 보증금(원)
 * @returns {number} 월 환산금액(원, 천원 단위 절사)
 */
export function convertDepositToMonthly(depositWon) {
  if (!Number.isFinite(depositWon) || depositWon < 0) {
    throw new Error("depositWon must be a non-negative number");
  }
  return Math.floor((depositWon * RENT_CONVERSION_RATE) / 12 / 1000) * 1000;
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
 * 군복무 보정 계산 (계단식).
 * - 의무복무 마친 제대군인이 아니면 보정 0년 (기본 19~39세 = 1986.1.1 ~ 2007.12.31).
 * - 제대군인 + 1년 미만 (1~11개월): +1년 → 1985.1.1 ~ 2007.12.31
 * - 제대군인 + 1년 이상 ~ 2년 미만 (12~23개월): +2년 → 1984.1.1 ~ 2007.12.31
 * - 제대군인 + 2년 이상 (24개월 이상): +3년 → 1983.1.1 ~ 2007.12.31
 *
 * 주의: militaryMonths가 0이면 의무복무를 안 한 것으로 간주 (isVeteran true여도 보정 0).
 *
 * @param {string} birthDate - "YYYY-MM-DD"
 * @param {boolean} isVeteran - 의무복무 마친 제대군인 여부
 * @param {number} militaryMonths - 복무 개월 수
 * @returns {{eligibilityExtension: 0|1|2|3, oldestAllowedBirthDate: string, youngestAllowedBirthDate: string}}
 */
export function calculateAgeWithMilitary(birthDate, isVeteran = false, militaryMonths = 0) {
  const months = Number.isFinite(militaryMonths) && militaryMonths > 0 ? Math.floor(militaryMonths) : 0;

  let extensionYears;
  if (!isVeteran || months === 0) {
    extensionYears = 0;
  } else if (months < 12) {
    extensionYears = 1;
  } else if (months < 24) {
    extensionYears = 2;
  } else {
    extensionYears = 3;
  }

  // 기본 oldestAllowed = 1986-01-01. 보정 적용 시 -extensionYears.
  const baseOldest = new Date(AGE_MIN_BIRTH_DATE);
  const adjustedOldest = new Date(baseOldest);
  adjustedOldest.setFullYear(adjustedOldest.getFullYear() - extensionYears);

  return {
    eligibilityExtension: extensionYears,
    oldestAllowedBirthDate: adjustedOldest.toISOString().slice(0, 10),
    youngestAllowedBirthDate: AGE_MAX_BIRTH_DATE,
  };
}

/**
 * 보증금/월세/소득 bucket 조건으로 4개 tier 중 어느 구간에 매칭되는지 결정.
 * - 1구간부터 순서대로 시도, 가장 좋은(낮은 rank = 높은 ratio) 구간 반환.
 * - 어느 구간에도 매칭 안 되면 null.
 *
 * 매칭 로직 (각 tier):
 *   deposit ≤ tier.deposit.max
 *   AND (rent ≤ tier.rent.max OR meetsRentLimit으로 해당 tier 환산 통과)
 *   AND 소득 bucket이 tier 자격 만족 (1구간은 within48to120, 2~4구간은 within48to150)
 *
 * @param {number} depositWon
 * @param {number} rentWon
 * @param {{within48to150: boolean, within48to120: boolean}} incomeRange
 * @returns {{rank: 1|2|3|4, ratio: number} | null}
 */
export function matchTier(depositWon, rentWon, incomeRange) {
  for (const tier of SELECTION_TIERS) {
    const depositOk = depositWon <= tier.deposit.max;

    let incomeOk;
    if (tier.rank === 1) {
      // 1구간만 120% 한도
      incomeOk = incomeRange.within48to120;
    } else {
      incomeOk = incomeRange.within48to150;
    }

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
