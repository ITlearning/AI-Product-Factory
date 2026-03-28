import {
  assertCharacterResult,
  CHARACTER_RESULT_STATUS,
  OBSERVATIONAL_DISCLAIMER
} from "./character-contract.js";

const CATEGORY_RULES = [
  {
    category: "reward",
    keywords: ["디저트", "아이스크림", "케이크", "도넛", "베이커리", "빵"]
  },
  {
    category: "cafe",
    keywords: ["카페", "커피", "스타벅스", "이디야", "메가", "컴포즈", "빽다방"]
  },
  {
    category: "delivery",
    keywords: ["배달", "요기요", "배민", "쿠팡이츠", "딜리버리"]
  },
  {
    category: "transport",
    keywords: ["택시", "버스", "지하철", "대리", "주차", "기차", "고속버스"]
  },
  {
    category: "convenience",
    keywords: ["편의점", "cu", "gs25", "세븐일레븐", "미니스톱"]
  },
  {
    category: "meal",
    keywords: ["샐러드", "식당", "도시락", "점심", "저녁", "김밥", "버거", "치킨", "분식"]
  },
  {
    category: "shopping",
    keywords: ["올리브영", "다이소", "쿠팡", "무신사", "네이버쇼핑", "마켓", "스토어"]
  },
  {
    category: "health",
    keywords: ["약국", "병원", "의원", "헬스", "운동"]
  }
];

const PROFILE_LIBRARY = {
  reward: {
    characterName: "퇴근 후 숨 돌리는 셀프 포상러",
    summary:
      "오늘 소비는 생존보다 회복에 조금 더 가까웠어요. 하루 끝에 작은 위로와 빠른 해결이 함께 모였습니다.",
    patternObservation:
      "저녁 시간대 소비와 보상성 지출이 겹치면서 스스로를 달래는 흐름이 보였어요.",
    tags: ["보상형", "회복우선형", "소액반복형"],
    nextMove: "내일은 보상 소비 하나만 남기고, 나머지는 미리 정한 선택지 안에서 골라보세요.",
    preferredCategories: ["reward", "cafe", "delivery", "transport", "convenience"]
  },
  convenience: {
    characterName: "시간을 아껴 쓴 빠른 해결사",
    summary:
      "오늘은 절약보다 빠른 해결이 더 중요했던 날처럼 읽혀요. 이동과 간편한 선택이 하루의 리듬을 이끌었습니다.",
    patternObservation:
      "이동과 즉시 해결형 소비가 이어져서 시간과 에너지를 아끼려는 흐름이 선명했어요.",
    tags: ["편의형", "이동형", "즉시해결형"],
    nextMove: "내일 한 번만 느린 선택을 남겨두면, 편의 비용이 어디서 커지는지 더 또렷하게 보일 거예요.",
    preferredCategories: ["transport", "delivery", "convenience", "shopping"]
  },
  smallSpender: {
    characterName: "조금씩 챙기는 잔지출 수집가",
    summary:
      "큰 한 방보다 자잘한 선택이 여러 번 이어진 하루였어요. 작은 결제들이 모여 오늘의 분위기를 만들었습니다.",
    patternObservation:
      "한 번은 가볍지만 여러 번 반복된 소비가 이어져 잔지출 패턴이 또렷하게 드러났어요.",
    tags: ["잔지출형", "소액반복형", "생활밀착형"],
    nextMove: "내일은 가장 자주 나온 지출 하나만 미리 정해두면, 새는 흐름을 부드럽게 줄이기 쉬워져요.",
    preferredCategories: ["convenience", "cafe", "meal", "reward"]
  },
  steady: {
    characterName: "리듬을 지킨 생활 균형러",
    summary:
      "오늘 소비는 크게 치우치기보다 생활 리듬을 따라 움직인 편이에요. 필요한 지출이 비교적 고르게 섞여 있습니다.",
    patternObservation:
      "식사와 이동, 생활형 지출이 과하게 튀지 않아서 일상 리듬이 유지된 하루로 읽혀요.",
    tags: ["균형형", "루틴형", "생활유지형"],
    nextMove: "내일도 가장 만족스러웠던 소비 하나를 기억해두면, 균형을 해치지 않는 기준점이 생겨요.",
    preferredCategories: ["meal", "transport", "convenience", "health"]
  }
};

/**
 * @typedef {{
 *   rawText: string;
 *   label: string;
 *   amount: number;
 *   amountText: string;
 *   category: string;
 *   hour: number | null;
 * }} ParsedTransaction
 */

/**
 * @param {number} amount
 * @returns {string}
 */
export function formatCurrency(amount) {
  return `${amount.toLocaleString("ko-KR")}원`;
}

/**
 * @param {string} input
 * @returns {ParsedTransaction[]}
 */
export function parseTransactions(input) {
  return input
    .split(/\r?\n/u)
    .map((line) => line.trim())
    .filter(Boolean)
    .map(parseTransactionLine)
    .filter(Boolean);
}

/**
 * @param {string} rawText
 * @returns {ParsedTransaction | null}
 */
function parseTransactionLine(rawText) {
  const amountPattern =
    /([0-9]{1,3}(?:,[0-9]{3})+|[0-9]{4,}|[0-9]{1,3}(?=\s*원(?:\s|$)))(\s*원)?/gu;
  let amountMatch = null;

  for (const match of rawText.matchAll(amountPattern)) {
    amountMatch = match;
  }

  if (!amountMatch || amountMatch.index === undefined) {
    return null;
  }

  const amount = Number(amountMatch[1].replaceAll(",", ""));

  if (!Number.isFinite(amount) || amount <= 0) {
    return null;
  }

  const timeMatch = rawText.match(/(^|\s)(\d{1,2})[:.](\d{2})(?=\s|$)/u);
  const parsedHour = timeMatch ? Number(timeMatch[2]) : null;
  const parsedMinute = timeMatch ? Number(timeMatch[3]) : null;
  const hour =
    parsedHour !== null &&
    Number.isInteger(parsedHour) &&
    Number.isInteger(parsedMinute) &&
    parsedHour >= 0 &&
    parsedHour <= 23 &&
    parsedMinute >= 0 &&
    parsedMinute <= 59
      ? parsedHour
      : null;
  const label = extractLabel(rawText, amountMatch).trim();

  if (!label) {
    return null;
  }

  return {
    rawText,
    label,
    amount,
    amountText: formatCurrency(amount),
    category: inferCategory(label),
    hour
  };
}

/**
 * @param {string} rawText
 * @param {RegExpMatchArray} amountMatch
 * @returns {string}
 */
function extractLabel(rawText, amountMatch) {
  const beforeAmount = rawText.slice(0, amountMatch.index).trim();
  const afterAmount = rawText.slice(amountMatch.index + amountMatch[0].length).trim();
  const joined = `${beforeAmount} ${afterAmount}`
    .replace(/\s+/gu, " ")
    .replace(/^\d{1,2}[:.]\d{2}\s*/u, "")
    .replace(/^[\-:]+/u, "")
    .trim();

  if (joined) {
    return joined;
  }

  return rawText
    .replace(amountMatch[0], "")
    .replace(/^\d{1,2}[:.]\d{2}\s*/u, "")
    .trim();
}

/**
 * @param {string} label
 * @returns {string}
 */
function inferCategory(label) {
  const normalizedLabel = label.toLowerCase();

  for (const rule of CATEGORY_RULES) {
    if (rule.keywords.some((keyword) => normalizedLabel.includes(keyword.toLowerCase()))) {
      return rule.category;
    }
  }

  return "other";
}

/**
 * @param {ParsedTransaction[]} transactions
 * @param {string} note
 */
function buildSignals(transactions, note) {
  const categoryCounts = {};
  const eveningCount = transactions.filter((transaction) => transaction.hour !== null && transaction.hour >= 18).length;
  const smallSpendCount = transactions.filter((transaction) => transaction.amount <= 15000).length;
  const totalAmount = transactions.reduce((sum, transaction) => sum + transaction.amount, 0);
  const noteMentionsFatigue = /야근|지친|피곤|힘든|바빴/u.test(note);

  for (const transaction of transactions) {
    categoryCounts[transaction.category] = (categoryCounts[transaction.category] ?? 0) + 1;
  }

  const rewardScore =
    (categoryCounts.reward ?? 0) * 2 +
    (categoryCounts.cafe ?? 0) +
    (categoryCounts.delivery ?? 0) +
    eveningCount +
    (noteMentionsFatigue ? 2 : 0);

  const convenienceScore =
    (categoryCounts.transport ?? 0) * 2 +
    (categoryCounts.delivery ?? 0) +
    (categoryCounts.convenience ?? 0) +
    (totalAmount >= 30000 ? 1 : 0);

  const smallSpenderScore =
    smallSpendCount +
    (transactions.length >= 4 ? 2 : 0) +
    ((categoryCounts.convenience ?? 0) >= 2 ? 1 : 0);

  return {
    categoryCounts,
    eveningCount,
    noteMentionsFatigue,
    rewardScore,
    convenienceScore,
    smallSpenderScore,
    totalAmount
  };
}

/**
 * @param {ReturnType<typeof buildSignals>} signals
 * @returns {keyof typeof PROFILE_LIBRARY}
 */
function selectProfile(signals) {
  if (signals.rewardScore >= 4 && signals.rewardScore >= signals.convenienceScore) {
    return "reward";
  }

  if (signals.convenienceScore >= 4 && signals.convenienceScore > signals.smallSpenderScore) {
    return "convenience";
  }

  if (signals.smallSpenderScore >= 5) {
    return "smallSpender";
  }

  return "steady";
}

/**
 * @param {keyof typeof PROFILE_LIBRARY} profileKey
 * @param {ParsedTransaction[]} transactions
 */
function buildEvidence(profileKey, transactions) {
  const profile = PROFILE_LIBRARY[profileKey];

  return [...transactions]
    .sort((left, right) => scoreEvidence(profile.preferredCategories, right) - scoreEvidence(profile.preferredCategories, left))
    .slice(0, Math.min(3, transactions.length))
    .map((transaction) => ({
      label: transaction.label,
      amountText: transaction.amountText,
      rawText: transaction.rawText,
      reason: describeEvidence(profileKey, transaction)
    }));
}

/**
 * @param {string[]} preferredCategories
 * @param {ParsedTransaction} transaction
 * @returns {number}
 */
function scoreEvidence(preferredCategories, transaction) {
  const categoryWeight = preferredCategories.includes(transaction.category) ? 20 : 0;
  const amountWeight = Math.min(Math.round(transaction.amount / 1000), 15);
  const timeWeight = transaction.hour !== null && transaction.hour >= 18 ? 3 : 0;
  return categoryWeight + amountWeight + timeWeight;
}

/**
 * @param {keyof typeof PROFILE_LIBRARY} profileKey
 * @param {ParsedTransaction} transaction
 * @returns {string}
 */
function describeEvidence(profileKey, transaction) {
  if (profileKey === "reward") {
    if (transaction.category === "reward" || transaction.category === "cafe") {
      return "작은 위로나 리프레시를 챙긴 소비로 보여요.";
    }

    if (transaction.category === "transport" || transaction.category === "delivery") {
      return "에너지보다 빠른 해결을 우선한 선택처럼 읽혀요.";
    }

    return "하루 끝의 컨디션을 챙기려는 흐름에 가까운 지출이에요.";
  }

  if (profileKey === "convenience") {
    if (transaction.category === "transport") {
      return "시간을 돈으로 바꿔서라도 빠르게 움직이려는 선택이 보였어요.";
    }

    if (transaction.category === "delivery" || transaction.category === "convenience") {
      return "조금 더 빠르고 가벼운 해결을 택한 장면으로 읽혀요.";
    }

    return "즉시 해결을 돕는 생활형 소비로 해석돼요.";
  }

  if (profileKey === "smallSpender") {
    return "한 번은 가볍지만 반복되면 분위기를 만드는 잔지출이에요.";
  }

  if (transaction.category === "meal" || transaction.category === "health") {
    return "생활 리듬을 유지하는 데 가까운 기본 지출이에요.";
  }

  return "오늘 소비의 균형을 만든 생활형 선택으로 보여요.";
}

/**
 * @param {string} rawInput
 * @param {{ note?: string }} [options]
 */
export function generateCharacterResult(rawInput, options = {}) {
  const note = options.note?.trim() ?? "";
  const rawLines = rawInput
    .split(/\r?\n/u)
    .map((line) => line.trim())
    .filter(Boolean);
  const transactions = parseTransactions(rawInput);
  const rawLineCount = rawLines.length;
  const parsedTransactionCount = transactions.length;
  const ignoredLineCount = Math.max(rawLineCount - parsedTransactionCount, 0);

  if (parsedTransactionCount === 0) {
    const result = {
      status: CHARACTER_RESULT_STATUS.PARSE_FAILED,
      disclaimer: OBSERVATIONAL_DISCLAIMER,
      rawLineCount,
      parsedTransactionCount,
      ignoredLineCount,
      message: "소비 문장에서 금액 패턴을 읽지 못했어요.",
      hint: "금액이 있는 소비 줄을 2개 이상 붙여넣어 주세요. 예: `07:42 편의점 4,800원`"
    };

    assertCharacterResult(result);
    return result;
  }

  if (parsedTransactionCount < 2) {
    const result = {
      status: CHARACTER_RESULT_STATUS.NEEDS_MORE_DATA,
      disclaimer: OBSERVATIONAL_DISCLAIMER,
      rawLineCount,
      parsedTransactionCount,
      ignoredLineCount,
      message: "캐릭터를 만들기엔 재료가 조금 부족해요.",
      hint: "금액이 있는 소비가 2건 이상 있으면 흐름을 더 안정적으로 읽을 수 있어요."
    };

    assertCharacterResult(result);
    return result;
  }

  const signals = buildSignals(transactions, note);
  const profileKey = selectProfile(signals);
  const profile = PROFILE_LIBRARY[profileKey];
  const result = {
    status: CHARACTER_RESULT_STATUS.SUCCESS,
    disclaimer: OBSERVATIONAL_DISCLAIMER,
    rawLineCount,
    parsedTransactionCount,
    ignoredLineCount,
    characterName: profile.characterName,
    summary: profile.summary,
    patternObservation: profile.patternObservation,
    tags: profile.tags,
    evidence: buildEvidence(profileKey, transactions),
    nextMove: profile.nextMove
  };

  assertCharacterResult(result);
  return result;
}
