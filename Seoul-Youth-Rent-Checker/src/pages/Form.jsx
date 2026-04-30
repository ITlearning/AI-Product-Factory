import { useEffect, useMemo, useReducer, useRef, useState } from "react";

import { submitCheck } from "../utils/clientApi.js";
import { saveDraft, loadDraft, clearDraft } from "../utils/formStorage.js";

/**
 * 8단계 자격 진단 폼.
 *
 * 상태: useReducer로 평탄화된 input 객체 + step 인덱스.
 * 진척: sessionStorage에 매 변경마다 저장. 새로고침 시 복원.
 * 분기: Step 3에서 가구형태별 부가 질문을 같은 step 안에 inline 노출.
 * 제출: Step 8 완료 → POST /api/check → uuid 받아서 onComplete(uuid).
 */

// --- 초기 상태 -------------------------------------------------------------

/**
 * evaluator EligibilityInput과 1:1 매핑.
 * 만원 단위 입력은 별도 필드(원 단위로 변환해서 input에 저장).
 */
const INITIAL_STATE = {
  step: 0, // 0~7 (0이 step 1)

  // Step 1
  birthDate: "",
  isVeteran: null, // null | true | false
  militaryStartDate: "",
  militaryEndDate: "",

  // Step 2
  nationalityStatus: "", // 'korean' | 'foreigner' | 'overseas-korean'
  residence: "", // '서울' | '서울 외'

  // Step 3
  householdType: "", // 'single' | 'single-parent' | 'fraud-victim' | 'young-newlywed' | 'youth-safe-housing'
  hasSinglParentCert: null,
  hasFraudVictimCert: null,
  youthSafeHousingType: null, // 'public' | 'private' | null
  // 신혼부부
  spouseBirthDate: "",
  spouseIsVeteran: null,
  spouseMilitaryStartDate: "",
  spouseMilitaryEndDate: "",
  spouseNationalityStatus: "",
  spouseInFamilyRegistry: null,
  spouseSameAddress: null,
  hasNewlywedChildren: null,

  // Step 4 — 보증금 / 월세 (만원 단위 입력)
  depositManwon: "",
  monthlyRentManwon: "",

  // Step 5 — 가구원 수 / 소득
  householdSize: "",
  monthlyIncomeManwon: "",

  // Step 6 — 재산 / 차량 (단순화)
  hasVehicle: null, // null | true | false
  vehicleValueManwon: "",
  ownsLandOrBuilding: null, // null | true | false

  // Step 7 — 주택 소유 / 임대인 / 공동임차
  ownsHome: null,
  landlordRelation: "", // 'spouse' | 'parent' | 'other' | 'cotenant'
  allCotenantsApplying: null,

  // Step 8 — multi-checkbox (모두 boolean)
  receivingNationalYouthRent: false,
  previouslyReceivedSeoulRent: false,
  receivingDistrictRent: false,
  receivingSeoulYouthAllowance: false,
  receivingTransitionYouthSupport: false,
  basicLivingRecipient: false,
  receivingSeoulHousingVoucher: false,
};

const TOTAL_STEPS = 8;

const EXCLUSION_KEYS = [
  "receivingNationalYouthRent",
  "previouslyReceivedSeoulRent",
  "receivingDistrictRent",
  "receivingSeoulYouthAllowance",
  "receivingTransitionYouthSupport",
  "basicLivingRecipient",
  "receivingSeoulHousingVoucher",
];

function reducer(state, action) {
  switch (action.type) {
    case "set":
      return { ...state, [action.key]: action.value };
    case "patch":
      return { ...state, ...action.patch };
    case "next":
      return { ...state, step: Math.min(state.step + 1, TOTAL_STEPS - 1) };
    case "prev":
      return { ...state, step: Math.max(state.step - 1, 0) };
    case "goto":
      return { ...state, step: action.step };
    case "hydrate":
      return { ...state, ...action.payload };
    case "reset":
      return { ...INITIAL_STATE };
    default:
      return state;
  }
}

// --- 헬퍼 ------------------------------------------------------------------

/**
 * 만원 입력값을 원 단위로 변환. 빈 문자열은 0.
 *
 * @param {string} manwon
 * @returns {number}
 */
function manwonToWon(manwon) {
  const num = Number(manwon);
  if (!Number.isFinite(num)) return 0;
  return Math.max(0, Math.floor(num)) * 10000;
}

/**
 * 시작/종료 날짜로부터 군복무 개월 수를 계산.
 * 잘못된 입력(빈 값, 역순, 음수)은 0으로 처리해서 의무복무 = N과 동일 효과.
 *
 * @param {string} start - "YYYY-MM-DD"
 * @param {string} end - "YYYY-MM-DD"
 * @returns {number}
 */
function calculateMilitaryMonths(start, end) {
  if (!start || !end) return 0;
  const s = new Date(start);
  const e = new Date(end);
  if (Number.isNaN(s.getTime()) || Number.isNaN(e.getTime())) return 0;
  if (e < s) return 0;
  const months =
    (e.getFullYear() - s.getFullYear()) * 12 + (e.getMonth() - s.getMonth());
  return Math.max(0, months);
}

/**
 * Form state → evaluator EligibilityInput.
 * 만원→원 변환, 미입력 boolean 디폴트, 신혼부부/한부모/전세사기 외엔 부가 필드 무시.
 *
 * @param {typeof INITIAL_STATE} s
 * @returns {object}
 */
function buildInput(s) {
  const isNewlywed = s.householdType === "young-newlywed";
  const isSingleParent = s.householdType === "single-parent";
  const isFraudVictim = s.householdType === "fraud-victim";
  const isYouthSafe = s.householdType === "youth-safe-housing";

  const militaryMonths =
    s.isVeteran === true
      ? calculateMilitaryMonths(s.militaryStartDate, s.militaryEndDate)
      : 0;

  const depositWon = manwonToWon(s.depositManwon);
  const vehicleValueWon =
    s.hasVehicle === true ? manwonToWon(s.vehicleValueManwon) : 0;
  // generalAssetWon = 보증금 + 차량 (사용자 직접 입력 X, 폼 자동 합산)
  const generalAssetWon = depositWon + vehicleValueWon;

  // 토지/건물 소유 = ownsHome 강제 true (Step 7 효과와 동일)
  const ownsHome = s.ownsLandOrBuilding === true || s.ownsHome === true;

  const input = {
    birthDate: s.birthDate,
    isVeteran: s.isVeteran === true,
    militaryMonths,

    nationalityStatus: s.nationalityStatus,
    residence: s.residence,

    householdType: s.householdType,
    hasSinglParentCert: isSingleParent ? s.hasSinglParentCert === true : false,
    hasFraudVictimCert: isFraudVictim ? s.hasFraudVictimCert === true : false,
    youthSafeHousingType: isYouthSafe ? s.youthSafeHousingType : null,

    hasNewlywedChildren: isNewlywed ? s.hasNewlywedChildren === true : false,

    depositWon,
    monthlyRentWon: manwonToWon(s.monthlyRentManwon),

    householdSize: Number(s.householdSize || 1),
    monthlyIncomeWon: manwonToWon(s.monthlyIncomeManwon),

    generalAssetWon,
    vehicleValueWon,

    ownsHome,
    landlordRelation: s.landlordRelation === "cotenant" ? "other" : s.landlordRelation,
    allCotenantsApplying:
      s.landlordRelation === "cotenant" ? s.allCotenantsApplying === true : false,

    receivingNationalYouthRent: !!s.receivingNationalYouthRent,
    previouslyReceivedSeoulRent: !!s.previouslyReceivedSeoulRent,
    receivingDistrictRent: !!s.receivingDistrictRent,
    receivingSeoulYouthAllowance: !!s.receivingSeoulYouthAllowance,
    receivingTransitionYouthSupport: !!s.receivingTransitionYouthSupport,
    basicLivingRecipient: !!s.basicLivingRecipient,
    receivingSeoulHousingVoucher: !!s.receivingSeoulHousingVoucher,
  };

  if (isNewlywed) {
    const spouseMilitaryMonths =
      s.spouseIsVeteran === true
        ? calculateMilitaryMonths(s.spouseMilitaryStartDate, s.spouseMilitaryEndDate)
        : 0;

    input.spouseBirthDate = s.spouseBirthDate || undefined;
    input.spouseIsVeteran = s.spouseIsVeteran === true;
    input.spouseMilitaryMonths = spouseMilitaryMonths;
    input.spouseNationalityStatus = s.spouseNationalityStatus || undefined;
    input.spouseInFamilyRegistry = s.spouseInFamilyRegistry === true;
    input.spouseSameAddress = s.spouseSameAddress === true;
  }

  return input;
}

/**
 * 현재 step의 입력이 다음으로 넘어가도 될 만큼 채워져 있는지 검증.
 * null 반환 = OK, 문자열 = 에러 메시지.
 *
 * @param {typeof INITIAL_STATE} s
 * @returns {string | null}
 */
function validateStep(s) {
  switch (s.step) {
    case 0: {
      // Step 1
      if (!s.birthDate) return "생년월일을 입력해 주세요.";
      const d = new Date(s.birthDate);
      if (Number.isNaN(d.getTime())) return "생년월일 형식이 올바르지 않아요.";
      if (s.isVeteran === null) return "제대군인 여부를 선택해 주세요.";
      if (s.isVeteran === true) {
        if (!s.militaryStartDate) return "복무 시작일을 입력해 주세요.";
        if (!s.militaryEndDate) return "복무 종료일을 입력해 주세요.";
        const start = new Date(s.militaryStartDate);
        const end = new Date(s.militaryEndDate);
        if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()))
          return "복무 날짜 형식이 올바르지 않아요.";
        if (end < start) return "복무 종료일이 시작일보다 빠를 수 없어요.";
      }
      return null;
    }
    case 1: {
      // Step 2
      if (!s.nationalityStatus) return "국적을 선택해 주세요.";
      if (!s.residence) return "현재 거주지를 선택해 주세요.";
      return null;
    }
    case 2: {
      // Step 3
      if (!s.householdType) return "가구 형태를 선택해 주세요.";
      if (s.householdType === "single-parent" && s.hasSinglParentCert === null)
        return "한부모가족증명서 보유 여부를 선택해 주세요.";
      if (s.householdType === "fraud-victim" && s.hasFraudVictimCert === null)
        return "전세사기피해자등 결정문 보유 여부를 선택해 주세요.";
      if (s.householdType === "youth-safe-housing" && !s.youthSafeHousingType)
        return "민간임대인지 공공임대인지 선택해 주세요.";
      if (s.householdType === "young-newlywed") {
        if (!s.spouseBirthDate) return "배우자 생년월일을 입력해 주세요.";
        if (s.spouseIsVeteran === null) return "배우자 제대군인 여부를 선택해 주세요.";
        if (s.spouseIsVeteran === true) {
          if (!s.spouseMilitaryStartDate) return "배우자 복무 시작일을 입력해 주세요.";
          if (!s.spouseMilitaryEndDate) return "배우자 복무 종료일을 입력해 주세요.";
          const start = new Date(s.spouseMilitaryStartDate);
          const end = new Date(s.spouseMilitaryEndDate);
          if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime()))
            return "배우자 복무 날짜 형식이 올바르지 않아요.";
          if (end < start) return "배우자 복무 종료일이 시작일보다 빠를 수 없어요.";
        }
        if (!s.spouseNationalityStatus) return "배우자 국적을 선택해 주세요.";
        if (s.spouseNationalityStatus !== "korean") {
          if (s.spouseInFamilyRegistry === null)
            return "배우자가 가족관계증명서에 등재되어 있는지 선택해 주세요.";
          if (s.spouseSameAddress === null)
            return "배우자와 주민등록 주소지가 같은지 선택해 주세요.";
        }
        if (s.hasNewlywedChildren === null) return "자녀 여부를 선택해 주세요.";
      }
      return null;
    }
    case 3: {
      // Step 4
      if (s.depositManwon === "" || Number(s.depositManwon) < 0)
        return "임차보증금을 입력해 주세요.";
      if (s.monthlyRentManwon === "" || Number(s.monthlyRentManwon) < 0)
        return "월세를 입력해 주세요.";
      return null;
    }
    case 4: {
      // Step 5
      const n = Number(s.householdSize);
      if (!Number.isFinite(n) || n < 1) return "가구원 수를 선택해 주세요.";
      if (s.monthlyIncomeManwon === "" || Number(s.monthlyIncomeManwon) < 0)
        return "가구 월소득을 입력해 주세요.";
      return null;
    }
    case 5: {
      // Step 6 — 차량 Y/N + 토지/건물 Y/N
      if (s.hasVehicle === null) return "차량 보유 여부를 선택해 주세요.";
      if (s.hasVehicle === true) {
        if (s.vehicleValueManwon === "" || Number(s.vehicleValueManwon) < 0)
          return "차량 시가표준액을 입력해 주세요.";
      }
      if (s.ownsLandOrBuilding === null)
        return "토지·건물 소유 여부를 선택해 주세요.";
      return null;
    }
    case 6: {
      // Step 7
      if (s.ownsHome === null) return "주택 소유 여부를 선택해 주세요.";
      if (!s.landlordRelation) return "임대인 관계를 선택해 주세요.";
      if (s.landlordRelation === "cotenant" && s.allCotenantsApplying === null)
        return "공동임차인 모두 신청 여부를 선택해 주세요.";
      return null;
    }
    case 7:
      // Step 8 — 체크박스는 모두 미체크여도 OK ('해당 없음' 의미)
      return null;
    default:
      return null;
  }
}

// --- 컴포넌트 --------------------------------------------------------------

export function Form({ onComplete, onBack }) {
  const [state, dispatch] = useReducer(reducer, INITIAL_STATE);
  const [error, setError] = useState(null);
  const [submitError, setSubmitError] = useState(null);
  const [submitting, setSubmitting] = useState(false);
  const stepRef = useRef(null);

  // 첫 렌더 시 sessionStorage 복원
  useEffect(() => {
    const draft = loadDraft();
    if (draft && typeof draft === "object") {
      dispatch({ type: "hydrate", payload: draft });
    }
  }, []);

  // state 변경 시 sessionStorage 자동 저장 (제출 직전 step 포함)
  useEffect(() => {
    saveDraft(state);
  }, [state]);

  // step 변경 시 상단 포커스/스크롤
  useEffect(() => {
    if (stepRef.current) {
      stepRef.current.focus({ preventScroll: true });
    }
    window.scrollTo({ top: 0, behavior: "smooth" });
  }, [state.step]);

  const set = (key) => (value) => {
    setError(null);
    dispatch({ type: "set", key, value });
  };

  const handleNext = async () => {
    const err = validateStep(state);
    if (err) {
      setError(err);
      return;
    }
    setError(null);

    if (state.step < TOTAL_STEPS - 1) {
      dispatch({ type: "next" });
      return;
    }

    // 마지막 step → 제출
    await submit();
  };

  const submit = async () => {
    setSubmitting(true);
    setSubmitError(null);
    try {
      const input = buildInput(state);
      const { uuid } = await submitCheck(input);
      clearDraft();
      onComplete?.(uuid);
    } catch (e) {
      setSubmitError(e instanceof Error ? e.message : "요청 실패");
    } finally {
      setSubmitting(false);
    }
  };

  const handlePrev = () => {
    setError(null);
    setSubmitError(null);
    if (state.step === 0) {
      onBack?.();
      return;
    }
    dispatch({ type: "prev" });
  };

  const handleKeyDown = (e) => {
    // Enter로 다음 — 단, textarea/checkbox는 자기 동작 보존
    if (e.key !== "Enter") return;
    const tag = (e.target.tagName || "").toLowerCase();
    const type = (e.target.type || "").toLowerCase();
    if (tag === "textarea") return;
    if (tag === "button") return; // 버튼 자체 클릭은 그대로
    if (type === "checkbox" || type === "radio") return;
    e.preventDefault();
    handleNext();
  };

  const progressPercent = useMemo(
    () => Math.round(((state.step + 1) / TOTAL_STEPS) * 100),
    [state.step]
  );

  const isLast = state.step === TOTAL_STEPS - 1;

  return (
    <main className="form" onKeyDown={handleKeyDown}>
      <div className="form__progress" aria-hidden="true">
        <div
          className="form__progress-fill"
          style={{ width: `${progressPercent}%` }}
        />
      </div>

      <div className="form__shell">
        <div
          className="form__step-indicator"
          aria-live="polite"
        >
          Step {state.step + 1} / {TOTAL_STEPS}
        </div>

        <div
          className="form__step"
          key={state.step}
          tabIndex={-1}
          ref={stepRef}
        >
          {state.step === 0 && <Step1 state={state} set={set} />}
          {state.step === 1 && <Step2 state={state} set={set} />}
          {state.step === 2 && <Step3 state={state} set={set} />}
          {state.step === 3 && <Step4 state={state} set={set} />}
          {state.step === 4 && <Step5 state={state} set={set} />}
          {state.step === 5 && <Step6 state={state} set={set} />}
          {state.step === 6 && <Step7 state={state} set={set} />}
          {state.step === 7 && (
            <Step8
              state={state}
              dispatch={dispatch}
            />
          )}
        </div>

        {error && (
          <p className="form__error" role="alert">
            {error}
          </p>
        )}
        {submitError && (
          <div className="form__submit-error" role="alert">
            <p>{submitError}</p>
            <button
              type="button"
              className="form__retry"
              onClick={submit}
              disabled={submitting}
            >
              다시 시도
            </button>
          </div>
        )}

        <div className="form__nav">
          <button
            type="button"
            className="form__back"
            onClick={handlePrev}
            disabled={submitting}
          >
            {state.step === 0 ? "처음으로" : "뒤로"}
          </button>
          <button
            type="button"
            className={isLast ? "form__cta" : "form__next"}
            onClick={handleNext}
            disabled={submitting}
          >
            {submitting
              ? "확인 중…"
              : isLast
                ? "자격 확인하기"
                : "다음"}
          </button>
        </div>
      </div>
    </main>
  );
}

// --- Step 컴포넌트들 ------------------------------------------------------

function Step1({ state, set }) {
  const months = calculateMilitaryMonths(
    state.militaryStartDate,
    state.militaryEndDate
  );
  const showMonthsHint =
    state.isVeteran === true &&
    state.militaryStartDate &&
    state.militaryEndDate &&
    months > 0;

  return (
    <>
      <h2 className="form__question">생년월일과 군복무 이력을 알려주세요.</h2>
      <p className="form__help">
        의무복무 마친 제대군인은 복무 기간만큼 최대 3년까지 연령 보정을 받아요.
      </p>

      <label className="form__label" htmlFor="birthDate">생년월일</label>
      <input
        id="birthDate"
        type="date"
        className="form__input"
        value={state.birthDate}
        min="1980-01-01"
        max="2010-12-31"
        onChange={(e) => set("birthDate")(e.target.value)}
      />

      <fieldset className="form__radio-group">
        <legend className="form__label">의무복무를 마친 제대군인이세요?</legend>
        <RadioCard
          name="isVeteran"
          checked={state.isVeteran === true}
          onChange={() => set("isVeteran")(true)}
          label="네"
        />
        <RadioCard
          name="isVeteran"
          checked={state.isVeteran === false}
          onChange={() => set("isVeteran")(false)}
          label="아니요"
        />
      </fieldset>

      {state.isVeteran === true && (
        <>
          <label className="form__label" htmlFor="militaryStartDate">
            복무 시작일
          </label>
          <input
            id="militaryStartDate"
            type="date"
            className="form__input"
            value={state.militaryStartDate}
            min="1990-01-01"
            max="2030-12-31"
            onChange={(e) => set("militaryStartDate")(e.target.value)}
          />

          <label className="form__label" htmlFor="militaryEndDate">
            복무 종료일 (전역일)
          </label>
          <input
            id="militaryEndDate"
            type="date"
            className="form__input"
            value={state.militaryEndDate}
            min="1990-01-01"
            max="2030-12-31"
            onChange={(e) => set("militaryEndDate")(e.target.value)}
          />

          <p className="form__hint">
            예: 2018-03-01 ~ 2019-12-31 (육군 약 21개월)
            {showMonthsHint && (
              <>
                <br />
                계산된 복무 기간: <strong>{months}개월</strong>
                {" "}— {months < 12
                  ? "+1년 보정"
                  : months < 24
                    ? "+2년 보정"
                    : "+3년 보정"}
              </>
            )}
          </p>
        </>
      )}
    </>
  );
}

function Step2({ state, set }) {
  return (
    <>
      <h2 className="form__question">국적과 거주지를 확인할게요.</h2>

      <fieldset className="form__radio-group">
        <legend className="form__label">국적</legend>
        <RadioCard
          name="nationalityStatus"
          checked={state.nationalityStatus === "korean"}
          onChange={() => set("nationalityStatus")("korean")}
          label="한국인"
        />
        <RadioCard
          name="nationalityStatus"
          checked={state.nationalityStatus === "foreigner"}
          onChange={() => set("nationalityStatus")("foreigner")}
          label="외국인"
        />
        <RadioCard
          name="nationalityStatus"
          checked={state.nationalityStatus === "overseas-korean"}
          onChange={() => set("nationalityStatus")("overseas-korean")}
          label="재외국민"
        />
      </fieldset>

      <fieldset className="form__radio-group">
        <legend className="form__label">현재 어디 살고 있어요?</legend>
        <RadioCard
          name="residence"
          checked={state.residence === "서울"}
          onChange={() => set("residence")("서울")}
          label="서울"
        />
        <RadioCard
          name="residence"
          checked={state.residence === "서울 외"}
          onChange={() => set("residence")("서울 외")}
          label="서울 외 지역"
        />
      </fieldset>
    </>
  );
}

function Step3({ state, set }) {
  const t = state.householdType;
  const spouseMonths = calculateMilitaryMonths(
    state.spouseMilitaryStartDate,
    state.spouseMilitaryEndDate
  );
  const showSpouseMonthsHint =
    state.spouseIsVeteran === true &&
    state.spouseMilitaryStartDate &&
    state.spouseMilitaryEndDate &&
    spouseMonths > 0;

  return (
    <>
      <h2 className="form__question">가구 형태를 알려주세요.</h2>
      <p className="form__help">선택에 따라 추가 질문이 나와요.</p>

      <fieldset className="form__radio-group">
        <legend className="form__label">가구 형태</legend>
        <RadioCard
          name="householdType"
          checked={t === "single"}
          onChange={() => set("householdType")("single")}
          label="1인 가구 (청년)"
        />
        <RadioCard
          name="householdType"
          checked={t === "single-parent"}
          onChange={() => set("householdType")("single-parent")}
          label="한부모 가구"
        />
        <RadioCard
          name="householdType"
          checked={t === "fraud-victim"}
          onChange={() => set("householdType")("fraud-victim")}
          label="전세사기 피해자"
        />
        <RadioCard
          name="householdType"
          checked={t === "young-newlywed"}
          onChange={() => set("householdType")("young-newlywed")}
          label="청년신혼부부 (혼인 7년 이내)"
        />
        <RadioCard
          name="householdType"
          checked={t === "youth-safe-housing"}
          onChange={() => set("householdType")("youth-safe-housing")}
          label="청년안심주택 거주자"
        />
      </fieldset>

      {t === "single-parent" && (
        <fieldset className="form__radio-group">
          <legend className="form__label">한부모가족증명서가 있어요?</legend>
          <RadioCard
            name="hasSinglParentCert"
            checked={state.hasSinglParentCert === true}
            onChange={() => set("hasSinglParentCert")(true)}
            label="네"
          />
          <RadioCard
            name="hasSinglParentCert"
            checked={state.hasSinglParentCert === false}
            onChange={() => set("hasSinglParentCert")(false)}
            label="아니요"
          />
        </fieldset>
      )}

      {t === "fraud-victim" && (
        <fieldset className="form__radio-group">
          <legend className="form__label">전세사기피해자등 결정문이 있어요?</legend>
          <RadioCard
            name="hasFraudVictimCert"
            checked={state.hasFraudVictimCert === true}
            onChange={() => set("hasFraudVictimCert")(true)}
            label="네"
          />
          <RadioCard
            name="hasFraudVictimCert"
            checked={state.hasFraudVictimCert === false}
            onChange={() => set("hasFraudVictimCert")(false)}
            label="아니요"
          />
        </fieldset>
      )}

      {t === "youth-safe-housing" && (
        <fieldset className="form__radio-group">
          <legend className="form__label">민간임대 / 공공임대 어느 쪽?</legend>
          <RadioCard
            name="youthSafeHousingType"
            checked={state.youthSafeHousingType === "private"}
            onChange={() => set("youthSafeHousingType")("private")}
            label="민간임대"
          />
          <RadioCard
            name="youthSafeHousingType"
            checked={state.youthSafeHousingType === "public"}
            onChange={() => set("youthSafeHousingType")("public")}
            label="공공임대"
          />
        </fieldset>
      )}

      {t === "young-newlywed" && (
        <div className="form__subgroup">
          <h3 className="form__subhead">배우자 정보</h3>

          <label className="form__label" htmlFor="spouseBirthDate">
            배우자 생년월일
          </label>
          <input
            id="spouseBirthDate"
            type="date"
            className="form__input"
            value={state.spouseBirthDate}
            min="1980-01-01"
            max="2010-12-31"
            onChange={(e) => set("spouseBirthDate")(e.target.value)}
          />

          <fieldset className="form__radio-group">
            <legend className="form__label">
              배우자도 의무복무를 마친 제대군인이세요?
            </legend>
            <RadioCard
              name="spouseIsVeteran"
              checked={state.spouseIsVeteran === true}
              onChange={() => set("spouseIsVeteran")(true)}
              label="네"
            />
            <RadioCard
              name="spouseIsVeteran"
              checked={state.spouseIsVeteran === false}
              onChange={() => set("spouseIsVeteran")(false)}
              label="아니요"
            />
          </fieldset>

          {state.spouseIsVeteran === true && (
            <>
              <label className="form__label" htmlFor="spouseMilitaryStartDate">
                배우자 복무 시작일
              </label>
              <input
                id="spouseMilitaryStartDate"
                type="date"
                className="form__input"
                value={state.spouseMilitaryStartDate}
                min="1990-01-01"
                max="2030-12-31"
                onChange={(e) => set("spouseMilitaryStartDate")(e.target.value)}
              />

              <label className="form__label" htmlFor="spouseMilitaryEndDate">
                배우자 복무 종료일 (전역일)
              </label>
              <input
                id="spouseMilitaryEndDate"
                type="date"
                className="form__input"
                value={state.spouseMilitaryEndDate}
                min="1990-01-01"
                max="2030-12-31"
                onChange={(e) => set("spouseMilitaryEndDate")(e.target.value)}
              />

              <p className="form__hint">
                예: 2018-03-01 ~ 2019-12-31 (육군 약 21개월)
                {showSpouseMonthsHint && (
                  <>
                    <br />
                    계산된 복무 기간: <strong>{spouseMonths}개월</strong>
                  </>
                )}
              </p>
            </>
          )}

          <fieldset className="form__radio-group">
            <legend className="form__label">배우자 국적</legend>
            <RadioCard
              name="spouseNationalityStatus"
              checked={state.spouseNationalityStatus === "korean"}
              onChange={() => set("spouseNationalityStatus")("korean")}
              label="한국인"
            />
            <RadioCard
              name="spouseNationalityStatus"
              checked={state.spouseNationalityStatus === "foreigner"}
              onChange={() => set("spouseNationalityStatus")("foreigner")}
              label="외국인"
            />
            <RadioCard
              name="spouseNationalityStatus"
              checked={state.spouseNationalityStatus === "overseas-korean"}
              onChange={() => set("spouseNationalityStatus")("overseas-korean")}
              label="재외국민"
            />
          </fieldset>

          {state.spouseNationalityStatus &&
            state.spouseNationalityStatus !== "korean" && (
              <>
                <fieldset className="form__radio-group">
                  <legend className="form__label">
                    배우자가 가족관계증명서에 등재되어 있어요?
                  </legend>
                  <RadioCard
                    name="spouseInFamilyRegistry"
                    checked={state.spouseInFamilyRegistry === true}
                    onChange={() => set("spouseInFamilyRegistry")(true)}
                    label="네"
                  />
                  <RadioCard
                    name="spouseInFamilyRegistry"
                    checked={state.spouseInFamilyRegistry === false}
                    onChange={() => set("spouseInFamilyRegistry")(false)}
                    label="아니요"
                  />
                </fieldset>

                <fieldset className="form__radio-group">
                  <legend className="form__label">
                    주민등록 주소지가 같아요?
                  </legend>
                  <RadioCard
                    name="spouseSameAddress"
                    checked={state.spouseSameAddress === true}
                    onChange={() => set("spouseSameAddress")(true)}
                    label="네"
                  />
                  <RadioCard
                    name="spouseSameAddress"
                    checked={state.spouseSameAddress === false}
                    onChange={() => set("spouseSameAddress")(false)}
                    label="아니요"
                  />
                </fieldset>
              </>
            )}

          <fieldset className="form__radio-group">
            <legend className="form__label">자녀가 있어요?</legend>
            <RadioCard
              name="hasNewlywedChildren"
              checked={state.hasNewlywedChildren === true}
              onChange={() => set("hasNewlywedChildren")(true)}
              label="네"
            />
            <RadioCard
              name="hasNewlywedChildren"
              checked={state.hasNewlywedChildren === false}
              onChange={() => set("hasNewlywedChildren")(false)}
              label="아니요"
            />
          </fieldset>
        </div>
      )}
    </>
  );
}

function Step4({ state, set }) {
  return (
    <>
      <h2 className="form__question">보증금과 월세를 입력해 주세요.</h2>
      <p className="form__help">
        월세 60만원 초과여도 보증금이 작으면 가능해요 (환산식 적용).
      </p>

      <label className="form__label" htmlFor="depositManwon">
        임차보증금
      </label>
      <div className="form__input-row">
        <input
          id="depositManwon"
          type="number"
          inputMode="numeric"
          min="0"
          step="100"
          className="form__input form__input--with-suffix"
          value={state.depositManwon}
          placeholder="예: 1000"
          onChange={(e) => set("depositManwon")(e.target.value)}
        />
        <span className="form__suffix">만원</span>
      </div>

      <label className="form__label" htmlFor="monthlyRentManwon">
        월세
      </label>
      <div className="form__input-row">
        <input
          id="monthlyRentManwon"
          type="number"
          inputMode="numeric"
          min="0"
          step="1"
          className="form__input form__input--with-suffix"
          value={state.monthlyRentManwon}
          placeholder="예: 55"
          onChange={(e) => set("monthlyRentManwon")(e.target.value)}
        />
        <span className="form__suffix">만원</span>
      </div>
    </>
  );
}

function Step5({ state, set }) {
  return (
    <>
      <h2 className="form__question">가구원 수와 월소득을 알려주세요.</h2>
      <p className="form__help">
        건강보험상 본인 가구의 평균 월소득(세전). 정확하지 않아도 OK — 결과는 안내용이에요.
      </p>

      <label className="form__label" htmlFor="householdSize">
        가구원 수
      </label>
      <select
        id="householdSize"
        className="form__input"
        value={state.householdSize}
        onChange={(e) => set("householdSize")(e.target.value)}
      >
        <option value="">선택</option>
        {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map((n) => (
          <option key={n} value={n}>
            {n}인
          </option>
        ))}
      </select>

      <label className="form__label" htmlFor="monthlyIncomeManwon">
        가구 월소득 (세전)
      </label>
      <div className="form__input-row">
        <input
          id="monthlyIncomeManwon"
          type="number"
          inputMode="numeric"
          min="0"
          step="1"
          className="form__input form__input--with-suffix"
          value={state.monthlyIncomeManwon}
          placeholder="예: 250"
          onChange={(e) => set("monthlyIncomeManwon")(e.target.value)}
        />
        <span className="form__suffix">만원</span>
      </div>
    </>
  );
}

function Step6({ state, set }) {
  return (
    <>
      <h2 className="form__question">차량과 부동산을 확인할게요.</h2>
      <p className="form__help">
        임차보증금이랑 차량 합쳐서 1.3억 넘으면 대상 아니에요. 대부분은 OK.
      </p>

      <fieldset className="form__radio-group">
        <legend className="form__label">차량 가지고 있어요?</legend>
        <RadioCard
          name="hasVehicle"
          checked={state.hasVehicle === true}
          onChange={() => set("hasVehicle")(true)}
          label="네"
        />
        <RadioCard
          name="hasVehicle"
          checked={state.hasVehicle === false}
          onChange={() => set("hasVehicle")(false)}
          label="아니요"
        />
      </fieldset>

      {state.hasVehicle === true && (
        <>
          <label className="form__label" htmlFor="vehicleValueManwon">
            차량 시가표준액
          </label>
          <div className="form__input-row">
            <input
              id="vehicleValueManwon"
              type="number"
              inputMode="numeric"
              min="0"
              step="10"
              className="form__input form__input--with-suffix"
              value={state.vehicleValueManwon}
              placeholder="예: 1500"
              onChange={(e) => set("vehicleValueManwon")(e.target.value)}
            />
            <span className="form__suffix">만원</span>
          </div>
          <p className="form__hint">
            잘 모르면 차량 등록증에 적힌 금액. 보통 5년 안 된 차는 1,500~2,500만 사이.
            2,500만원 이상이면 신청 불가.
          </p>
        </>
      )}

      <fieldset className="form__radio-group">
        <legend className="form__label">
          토지나 건물 소유 중이에요? (분양권·오피스텔 포함)
        </legend>
        <RadioCard
          name="ownsLandOrBuilding"
          checked={state.ownsLandOrBuilding === true}
          onChange={() => set("ownsLandOrBuilding")(true)}
          label="네"
        />
        <RadioCard
          name="ownsLandOrBuilding"
          checked={state.ownsLandOrBuilding === false}
          onChange={() => set("ownsLandOrBuilding")(false)}
          label="아니요"
        />
      </fieldset>

      {state.ownsLandOrBuilding === true && (
        <p className="form__hint form__hint--warning">
          이 사업은 무주택 청년 대상이라 토지·건물 소유자는 신청할 수 없어요.
          그래도 진단을 끝까지 진행하면 다른 적합 프로그램을 안내해 드려요.
        </p>
      )}
    </>
  );
}

function Step7({ state, set }) {
  return (
    <>
      <h2 className="form__question">주택 소유와 임대인 관계를 확인할게요.</h2>

      <fieldset className="form__radio-group">
        <legend className="form__label">
          주택을 소유 중이에요? (분양권·오피스텔·공유지분 포함)
        </legend>
        <RadioCard
          name="ownsHome"
          checked={state.ownsHome === true}
          onChange={() => set("ownsHome")(true)}
          label="네"
        />
        <RadioCard
          name="ownsHome"
          checked={state.ownsHome === false}
          onChange={() => set("ownsHome")(false)}
          label="아니요"
        />
      </fieldset>

      <fieldset className="form__radio-group">
        <legend className="form__label">임대인이 누구예요?</legend>
        <RadioCard
          name="landlordRelation"
          checked={state.landlordRelation === "spouse"}
          onChange={() => set("landlordRelation")("spouse")}
          label="배우자"
        />
        <RadioCard
          name="landlordRelation"
          checked={state.landlordRelation === "parent"}
          onChange={() => set("landlordRelation")("parent")}
          label="부모"
        />
        <RadioCard
          name="landlordRelation"
          checked={state.landlordRelation === "other"}
          onChange={() => set("landlordRelation")("other")}
          label="그 외 (제3자)"
        />
        <RadioCard
          name="landlordRelation"
          checked={state.landlordRelation === "cotenant"}
          onChange={() => set("landlordRelation")("cotenant")}
          label="공동임차 계약이에요"
        />
      </fieldset>

      {state.landlordRelation === "cotenant" && (
        <fieldset className="form__radio-group">
          <legend className="form__label">공동임차인 모두 신청할 예정이에요?</legend>
          <RadioCard
            name="allCotenantsApplying"
            checked={state.allCotenantsApplying === true}
            onChange={() => set("allCotenantsApplying")(true)}
            label="네, 모두 신청"
          />
          <RadioCard
            name="allCotenantsApplying"
            checked={state.allCotenantsApplying === false}
            onChange={() => set("allCotenantsApplying")(false)}
            label="아니요, 1명만 신청"
          />
        </fieldset>
      )}
    </>
  );
}

const EXCLUSION_OPTIONS = [
  {
    key: "receivingNationalYouthRent",
    label: "국토부 청년월세 한시지원 수혜 중",
  },
  {
    key: "previouslyReceivedSeoulRent",
    label: "서울시 청년월세지원을 이미 받은 적이 있음",
  },
  {
    key: "receivingDistrictRent",
    label: "자치구 청년월세지원 수혜 중 (은평·광진·동작·관악 등)",
  },
  {
    key: "receivingSeoulYouthAllowance",
    label: "서울시 청년수당 수령 중",
  },
  {
    key: "receivingTransitionYouthSupport",
    label: "자립준비청년 월세·기숙사비 지원 수령 중",
  },
  {
    key: "basicLivingRecipient",
    label: "국민기초생활수급 대상자",
  },
  {
    key: "receivingSeoulHousingVoucher",
    label: "서울형 주택바우처 수령 중",
  },
];

function Step8({ state, dispatch }) {
  const noneSelected = EXCLUSION_KEYS.every((k) => state[k] === false);

  const toggle = (key) => {
    dispatch({ type: "set", key, value: !state[key] });
  };

  const selectNone = () => {
    const patch = {};
    for (const k of EXCLUSION_KEYS) patch[k] = false;
    dispatch({ type: "patch", patch });
  };

  return (
    <>
      <h2 className="form__question">
        이미 받고 있거나 받았던 지원이 있나요?
      </h2>
      <p className="form__help">
        해당하는 항목을 모두 선택하세요. 중복 수령 제한 때문에 자격에 영향을 줘요.
      </p>

      <div className="form__checkbox-group">
        {EXCLUSION_OPTIONS.map((opt) => (
          <label key={opt.key} className="form__checkbox">
            <input
              type="checkbox"
              checked={!!state[opt.key]}
              onChange={() => toggle(opt.key)}
            />
            <span>{opt.label}</span>
          </label>
        ))}

        <label className="form__checkbox form__checkbox--none">
          <input
            type="checkbox"
            checked={noneSelected}
            onChange={() => {
              if (!noneSelected) selectNone();
            }}
          />
          <span>해당 없음</span>
        </label>
      </div>
    </>
  );
}

// --- 작은 빌딩블록 --------------------------------------------------------

function RadioCard({ name, checked, onChange, label }) {
  return (
    <label className={"form__radio" + (checked ? " form__radio--on" : "")}>
      <input
        type="radio"
        name={name}
        checked={checked}
        onChange={onChange}
      />
      <span>{label}</span>
    </label>
  );
}
