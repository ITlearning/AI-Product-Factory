/**
 * Pick one random item from an array.
 * @template T
 * @param {T[]} pool
 * @returns {T}
 */
export function pickOne(pool) {
  if (!pool || pool.length === 0) {
    throw new Error("pickOne: pool must be non-empty");
  }
  return pool[Math.floor(Math.random() * pool.length)];
}

/**
 * Pick one random item that is different from `previous`.
 * Guaranteed to differ from `previous` when pool has more than one distinct value.
 * @template T
 * @param {T[]} pool
 * @param {T} previous
 * @returns {T}
 */
export function pickOneDifferent(pool, previous) {
  const pick = pickOne(pool);
  if (pool.length === 1 || pick !== previous) return pick;
  const candidates = pool.filter((item) => item !== previous);
  if (candidates.length === 0) return pick;
  return pickOne(candidates);
}
