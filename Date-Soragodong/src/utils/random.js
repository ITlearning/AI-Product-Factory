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
 * Makes at most one retry — not guaranteed to differ if pool has only one item.
 * @template T
 * @param {T[]} pool
 * @param {T} previous
 * @returns {T}
 */
export function pickOneDifferent(pool, previous) {
  const pick = pickOne(pool);
  if (pool.length === 1 || pick !== previous) return pick;
  // One retry
  const retry = pickOne(pool);
  return retry;
}
