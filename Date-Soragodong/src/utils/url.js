/**
 * Single source of truth for URL construction.
 * Both the result page and the OG API consume these functions.
 */

/**
 * Build the shareable result URL.
 * @param {{ place: string, food: string, transport: string, budget: string }} course
 * @param {string} [base] — defaults to current origin
 * @returns {string}
 */
export function buildResultUrl(course, base = "") {
  const params = new URLSearchParams({
    place: course.place,
    food: course.food,
    transport: course.transport,
    budget: course.budget,
  });
  return `${base}/result?${params.toString()}`;
}

/**
 * Build the OG image URL from a course (or raw URLSearchParams).
 * @param {{ place: string, food: string, transport: string, budget: string }} course
 * @param {string} [base]
 * @returns {string}
 */
export function buildOgUrl(course, base = "") {
  const params = new URLSearchParams({
    place: course.place,
    food: course.food,
    transport: course.transport,
    budget: course.budget,
  });
  return `${base}/api/og?${params.toString()}`;
}

/**
 * Parse a course from URLSearchParams (for the result page).
 * Returns null if any required field is missing.
 * @param {URLSearchParams} params
 * @returns {{ place: string, food: string, transport: string, budget: string } | null}
 */
export function parseCourseFromParams(params) {
  const place = params.get("place");
  const food = params.get("food");
  const transport = params.get("transport");
  const budget = params.get("budget");
  if (!place || !food || !transport || !budget) return null;
  return { place, food, transport, budget };
}
