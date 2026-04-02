import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { pickOne, pickOneDifferent } from "../../src/utils/random.js";

describe("pickOne", () => {
  test("returns a value from the pool", () => {
    const pool = ["a", "b", "c"];
    const result = pickOne(pool);
    assert.ok(pool.includes(result), `Expected ${result} to be in pool`);
  });

  test("works with a single-element pool", () => {
    assert.equal(pickOne(["only"]), "only");
  });

  test("throws on empty pool", () => {
    assert.throws(() => pickOne([]), /non-empty/);
  });

  test("throws on null pool", () => {
    assert.throws(() => pickOne(null), /non-empty/);
  });

  test("distribution is roughly uniform (smoke)", () => {
    const pool = ["a", "b", "c", "d"];
    const counts = { a: 0, b: 0, c: 0, d: 0 };
    const iterations = 1000;
    for (let i = 0; i < iterations; i++) {
      counts[pickOne(pool)]++;
    }
    for (const key of pool) {
      // Each item should appear between 10% and 40% of the time
      const ratio = counts[key] / iterations;
      assert.ok(ratio > 0.1 && ratio < 0.4,
        `Unexpected distribution for "${key}": ${ratio}`
      );
    }
  });
});

describe("pickOneDifferent", () => {
  test("avoids returning previous value when pool has multiple items", () => {
    const pool = ["a", "b", "c", "d", "e"];
    let sameCount = 0;
    const iterations = 200;
    for (let i = 0; i < iterations; i++) {
      const result = pickOneDifferent(pool, "a");
      if (result === "a") sameCount++;
    }
    // With retry logic, same value rate should be very low (< 10%)
    assert.ok(sameCount / iterations < 0.1,
      `Too many same-value picks: ${sameCount}/${iterations}`
    );
  });

  test("returns the only item when pool has one element", () => {
    assert.equal(pickOneDifferent(["only"], "only"), "only");
  });

  test("always returns a value from the pool", () => {
    const pool = ["x", "y", "z"];
    for (let i = 0; i < 50; i++) {
      const result = pickOneDifferent(pool, "x");
      assert.ok(pool.includes(result));
    }
  });
});
