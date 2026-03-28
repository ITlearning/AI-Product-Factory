import test from "node:test";
import assert from "node:assert/strict";

import { generateCharacterResult } from "../../src/character-engine.js";
import { SAMPLE_NOTE, SAMPLE_TRANSACTIONS } from "../../src/content.js";
import {
  HISTORY_LIMIT,
  HISTORY_STORAGE_KEY,
  createHistoryEntry,
  formatHistoryTimestamp,
  loadHistoryEntries,
  recordHistoryEntry,
  saveHistoryEntries
} from "../../src/history.js";

test("formats history timestamps with zero-padded month, date, and time", () => {
  assert.equal(
    formatHistoryTimestamp(new Date(2026, 2, 28, 8, 5, 0)),
    "2026.03.28 08:05"
  );
});

test("records the latest history entry first while keeping the limit", () => {
  const seedEntries = Array.from({ length: HISTORY_LIMIT }, (_, index) =>
    createSuccessEntry({
      note: `seed-${index}`,
      now: new Date(`2026-03-28T09:0${index}:00Z`),
      rawInput: `${SAMPLE_TRANSACTIONS[0]}\n${index + 1}번째 소비 ${index + 1},000원`
    })
  );
  const latestEntry = createSuccessEntry({
    note: "latest",
    now: new Date("2026-03-28T09:59:00Z")
  });
  const nextEntries = recordHistoryEntry(latestEntry, seedEntries);

  assert.equal(nextEntries.length, HISTORY_LIMIT);
  assert.equal(nextEntries[0].id, latestEntry.id);
  assert.ok(nextEntries.every((entry) => entry.result.status === "success"));
});

test("round-trips shallow history entries through storage", () => {
  const storage = createMemoryStorage();
  const historyEntry = createSuccessEntry({
    note: "roundtrip",
    now: new Date("2026-03-28T09:45:00Z")
  });

  assert.equal(saveHistoryEntries(storage, [historyEntry]), true);
  assert.deepEqual(loadHistoryEntries(storage), [historyEntry]);
  assert.ok(storage.getItem(HISTORY_STORAGE_KEY));
});

test("ignores storage payloads with the wrong version or invalid entries", () => {
  const storage = createMemoryStorage();

  storage.setItem(
    HISTORY_STORAGE_KEY,
    JSON.stringify({
      version: 999,
      entries: [{ id: "broken" }]
    })
  );

  assert.deepEqual(loadHistoryEntries(storage), []);
});

/**
 * @param {{ note?: string; now?: Date; rawInput?: string }} [options]
 */
function createSuccessEntry(options = {}) {
  const rawInput = options.rawInput ?? SAMPLE_TRANSACTIONS.join("\n");
  const result = generateCharacterResult(rawInput, {
    note: options.note ?? SAMPLE_NOTE
  });

  if (result.status !== "success") {
    throw new Error("Expected sample history entry to be a success result");
  }

  return createHistoryEntry({
    now: options.now ?? new Date("2026-03-28T09:00:00Z"),
    note: options.note ?? SAMPLE_NOTE,
    rawInput,
    result
  });
}

function createMemoryStorage() {
  const values = new Map();

  return {
    getItem(key) {
      return values.has(key) ? values.get(key) : null;
    },
    setItem(key, value) {
      values.set(key, String(value));
    }
  };
}
