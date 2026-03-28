import { assertCharacterResult, CHARACTER_RESULT_STATUS } from "./character-contract.js";

export const HISTORY_STORAGE_KEY = "spending-personality/recent-character-history";
export const HISTORY_STORAGE_VERSION = 1;
export const HISTORY_LIMIT = 5;

/**
 * @param {number} value
 * @returns {string}
 */
function padNumber(value) {
  return String(value).padStart(2, "0");
}

/**
 * @param {Date} value
 * @returns {string}
 */
export function formatHistoryTimestamp(value) {
  if (!(value instanceof Date) || Number.isNaN(value.getTime())) {
    throw new Error("History timestamp must be a valid date");
  }

  return `${value.getFullYear()}.${padNumber(value.getMonth() + 1)}.${padNumber(value.getDate())} ${padNumber(value.getHours())}:${padNumber(value.getMinutes())}`;
}

/**
 * @param {string} value
 * @returns {string}
 */
function slugify(value) {
  return value
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[^\p{Letter}\p{Number}]+/gu, "-")
    .replace(/^-+|-+$/gu, "")
    .slice(0, 40);
}

/**
 * @param {unknown} storage
 * @returns {storage is Pick<Storage, "getItem" | "setItem">}
 */
function isStorageLike(storage) {
  return Boolean(
    storage &&
      typeof storage === "object" &&
      typeof storage.getItem === "function" &&
      typeof storage.setItem === "function"
  );
}

/**
 * @param {unknown} entry
 * @returns {boolean}
 */
function isHistoryEntry(entry) {
  try {
    if (!entry || typeof entry !== "object") {
      return false;
    }

    if (typeof entry.id !== "string" || entry.id.trim().length === 0) {
      return false;
    }

    if (typeof entry.createdAt !== "string" || entry.createdAt.trim().length === 0) {
      return false;
    }

    if (typeof entry.rawInput !== "string") {
      return false;
    }

    if (typeof entry.note !== "string") {
      return false;
    }

    assertCharacterResult(entry.result);
    return entry.result.status === CHARACTER_RESULT_STATUS.SUCCESS;
  } catch {
    return false;
  }
}

/**
 * @param {unknown} value
 * @returns {Array<object>}
 */
function normalizeHistoryEntries(value) {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.filter(isHistoryEntry);
}

/**
 * @param {object} entry
 * @param {object[]} historyEntries
 * @param {number} [limit]
 * @returns {object[]}
 */
export function recordHistoryEntry(entry, historyEntries, limit = HISTORY_LIMIT) {
  const nextEntries = [entry, ...historyEntries.filter((currentEntry) => currentEntry.id !== entry.id)];
  return nextEntries.slice(0, limit);
}

/**
 * @param {Pick<Storage, "getItem" | "setItem"> | null | undefined} storage
 * @returns {object[]}
 */
export function loadHistoryEntries(storage) {
  if (!isStorageLike(storage)) {
    return [];
  }

  try {
    const rawValue = storage.getItem(HISTORY_STORAGE_KEY);

    if (!rawValue) {
      return [];
    }

    const parsedValue = JSON.parse(rawValue);

    if (
      !parsedValue ||
      typeof parsedValue !== "object" ||
      parsedValue.version !== HISTORY_STORAGE_VERSION
    ) {
      return [];
    }

    return normalizeHistoryEntries(parsedValue.entries);
  } catch {
    return [];
  }
}

/**
 * @param {Pick<Storage, "getItem" | "setItem"> | null | undefined} storage
 * @param {object[]} historyEntries
 * @returns {boolean}
 */
export function saveHistoryEntries(storage, historyEntries) {
  if (!isStorageLike(storage)) {
    return false;
  }

  try {
    storage.setItem(
      HISTORY_STORAGE_KEY,
      JSON.stringify({
        version: HISTORY_STORAGE_VERSION,
        entries: historyEntries
      })
    );
    return true;
  } catch {
    return false;
  }
}

/**
 * @param {{
 *   now?: Date;
 *   note?: string;
 *   rawInput: string;
 *   result: object;
 * }} options
 * @returns {object}
 */
export function createHistoryEntry({ now = new Date(), note = "", rawInput, result }) {
  assertCharacterResult(result);

  if (result.status !== CHARACTER_RESULT_STATUS.SUCCESS) {
    throw new Error("Only success results can be stored in history");
  }

  const createdAt = formatHistoryTimestamp(now);

  return {
    id: `${now.getTime()}-${slugify(result.characterName)}-${rawInput.trim().length}`,
    createdAt,
    rawInput: rawInput.trim(),
    note: note.trim(),
    result
  };
}
