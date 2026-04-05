import { CONFIG } from './config.js';

/** @type {Map<string, { timestamps: number[] }>} */
const store = new Map();

const WINDOW_MS = 60_000; // 1 minute

/**
 * Check if a request from the given IP is allowed.
 * Best-effort in-memory rate limiter (resets on cold start).
 *
 * @param {string} ip
 * @returns {{ allowed: true } | { allowed: false, retryAfter: number }}
 */
export function checkRateLimit(ip) {
  const now = Date.now();
  let entry = store.get(ip);

  if (!entry) {
    entry = { timestamps: [] };
    store.set(ip, entry);
  }

  // Remove timestamps outside the current window
  entry.timestamps = entry.timestamps.filter((t) => now - t < WINDOW_MS);

  if (entry.timestamps.length >= CONFIG.RATE_LIMIT_PER_MINUTE) {
    const oldest = entry.timestamps[0];
    const retryAfter = Math.ceil((oldest + WINDOW_MS - now) / 1000);
    return { allowed: false, retryAfter };
  }

  entry.timestamps.push(now);
  return { allowed: true };
}
