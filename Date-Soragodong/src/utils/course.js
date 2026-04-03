import cards from "../data/cards.json" with { type: "json" };
import { pickOne, pickOneDifferent } from "./random.js";

/**
 * @typedef {{ place: string, food: string, transport: string, budget: string }} Course
 */

/**
 * Draw a random course.
 * Each category uses the full card pool unless a non-empty filter is provided.
 *
 * @param {{
 *   placeFilter?: string[],
 *   foodFilter?: string[],
 *   transportFilter?: string[],
 *   budgetFilter?: string[]
 * }} [filters]
 * @returns {Course}
 */
export function drawCourse(filters = {}) {
  const pool = {
    place: filters.placeFilter?.length ? filters.placeFilter : cards["갈_곳"],
    food: filters.foodFilter?.length ? filters.foodFilter : cards["먹을_곳"],
    transport: filters.transportFilter?.length ? filters.transportFilter : cards["탈_것"],
    budget: filters.budgetFilter?.length ? filters.budgetFilter : cards["금액"],
  };

  return {
    place: pickOne(pool.place),
    food: pickOne(pool.food),
    transport: pickOne(pool.transport),
    budget: pickOne(pool.budget),
  };
}

/**
 * Redraw a course, making at least one category different from the previous.
 * Retries once per category to avoid identical results.
 *
 * @param {Course} previous
 * @param {{
 *   placeFilter?: string[],
 *   foodFilter?: string[],
 *   transportFilter?: string[],
 *   budgetFilter?: string[]
 * }} [filters]
 * @returns {Course}
 */
export function redrawCourse(previous, filters = {}) {
  const pool = {
    place: filters.placeFilter?.length ? filters.placeFilter : cards["갈_곳"],
    food: filters.foodFilter?.length ? filters.foodFilter : cards["먹을_곳"],
    transport: filters.transportFilter?.length ? filters.transportFilter : cards["탈_것"],
    budget: filters.budgetFilter?.length ? filters.budgetFilter : cards["금액"],
  };

  const next = {
    place: pickOneDifferent(pool.place, previous.place),
    food: pickOneDifferent(pool.food, previous.food),
    transport: pickOneDifferent(pool.transport, previous.transport),
    budget: pickOneDifferent(pool.budget, previous.budget),
  };

  if (!isSameCourse(next, previous)) return next;

  // Fallback: force-change one mutable field (handles single-item pools)
  const poolByKey = { place: pool.place, food: pool.food, transport: pool.transport, budget: pool.budget };
  const mutableKeys = Object.keys(poolByKey).filter((key) =>
    poolByKey[key].some((v) => v !== previous[key])
  );
  if (mutableKeys.length === 0) return next;

  const key = pickOne(mutableKeys);
  const alternatives = poolByKey[key].filter((v) => v !== previous[key]);
  return { ...next, [key]: pickOne(alternatives) };
}

/**
 * Check if two courses are identical in all four fields.
 * @param {Course} a
 * @param {Course} b
 * @returns {boolean}
 */
export function isSameCourse(a, b) {
  return a.place === b.place && a.food === b.food &&
         a.transport === b.transport && a.budget === b.budget;
}
