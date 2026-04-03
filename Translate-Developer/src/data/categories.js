export const LANGUAGE_CATEGORIES = [
  {
    id: "developer",
    label: "개발자어",
    description: "개발자가 쓰는 기술 표현을 알기 쉽게 풀어드립니다."
  },
  {
    id: "designer",
    label: "디자이너어",
    description: "디자이너가 쓰는 전문 표현을 알기 쉽게 풀어드립니다."
  }
];

export const DEFAULT_CATEGORY = LANGUAGE_CATEGORIES[0].id;

/**
 * @param {unknown} value
 * @returns {boolean}
 */
export function isValidCategoryId(value) {
  return LANGUAGE_CATEGORIES.some((category) => category.id === value);
}

/**
 * @param {unknown} value
 * @returns {string}
 */
export function normalizeCategoryId(value) {
  return isValidCategoryId(value) ? value : DEFAULT_CATEGORY;
}

/**
 * @param {string} categoryId
 */
export function getCategoryOption(categoryId) {
  return LANGUAGE_CATEGORIES.find((category) => category.id === categoryId) ?? LANGUAGE_CATEGORIES[0];
}
