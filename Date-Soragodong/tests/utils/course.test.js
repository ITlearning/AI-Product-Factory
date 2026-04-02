import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { drawCourse, redrawCourse, isSameCourse } from "../../src/utils/course.js";
import cards from "../../src/data/cards.json" with { type: "json" };

describe("drawCourse", () => {
  test("returns all four fields", () => {
    const course = drawCourse();
    assert.ok(course.place, "place is required");
    assert.ok(course.food, "food is required");
    assert.ok(course.transport, "transport is required");
    assert.ok(course.budget, "budget is required");
  });

  test("each field comes from the full card pool by default", () => {
    for (let i = 0; i < 30; i++) {
      const course = drawCourse();
      assert.ok(cards["갈_곳"].includes(course.place), `Unknown place: ${course.place}`);
      assert.ok(cards["먹을_곳"].includes(course.food), `Unknown food: ${course.food}`);
      assert.ok(cards["탈_것"].includes(course.transport), `Unknown transport: ${course.transport}`);
      assert.ok(cards["금액"].includes(course.budget), `Unknown budget: ${course.budget}`);
    }
  });

  test("respects non-empty filter", () => {
    const filter = { placeFilter: ["카페", "공원"] };
    for (let i = 0; i < 50; i++) {
      const course = drawCourse(filter);
      assert.ok(["카페", "공원"].includes(course.place),
        `Expected place in filter, got: ${course.place}`
      );
    }
  });

  test("ignores empty filter (falls back to full pool)", () => {
    const filter = { placeFilter: [] };
    const course = drawCourse(filter);
    assert.ok(cards["갈_곳"].includes(course.place));
  });

  test("partial filters leave unfiltered categories open", () => {
    const filter = { budgetFilter: ["1만원 이하"] };
    for (let i = 0; i < 20; i++) {
      const course = drawCourse(filter);
      assert.equal(course.budget, "1만원 이하");
      assert.ok(cards["갈_곳"].includes(course.place));
    }
  });
});

describe("redrawCourse", () => {
  const previous = { place: "카페", food: "한식", transport: "도보", budget: "1만원 이하" };

  test("returns all four fields", () => {
    const next = redrawCourse(previous);
    assert.ok(next.place && next.food && next.transport && next.budget);
  });

  test("tries to produce a different result", () => {
    let sameCount = 0;
    const iterations = 100;
    for (let i = 0; i < iterations; i++) {
      if (isSameCourse(redrawCourse(previous), previous)) sameCount++;
    }
    // Should differ in at least some runs (very unlikely to be identical every time)
    assert.ok(sameCount < iterations,
      "redrawCourse never differed from previous"
    );
  });
});

describe("isSameCourse", () => {
  const course = { place: "한강", food: "분식", transport: "자전거", budget: "1-3만원" };

  test("returns true for identical courses", () => {
    assert.equal(isSameCourse(course, { ...course }), true);
  });

  test("returns false when any field differs", () => {
    assert.equal(isSameCourse(course, { ...course, place: "카페" }), false);
    assert.equal(isSameCourse(course, { ...course, food: "일식" }), false);
    assert.equal(isSameCourse(course, { ...course, transport: "택시" }), false);
    assert.equal(isSameCourse(course, { ...course, budget: "3-5만원" }), false);
  });
});
