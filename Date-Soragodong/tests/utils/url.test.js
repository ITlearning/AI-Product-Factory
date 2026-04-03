import { test, describe } from "node:test";
import assert from "node:assert/strict";
import { buildResultUrl, buildOgUrl, parseCourseFromParams } from "../../src/utils/url.js";

const COURSE = {
  place: "한강",
  food: "편의점 픽닉",
  transport: "따릉이",
  budget: "1-3만원",
};

describe("buildResultUrl", () => {
  test("produces a URL with /result path", () => {
    const url = buildResultUrl(COURSE);
    assert.ok(url.startsWith("/result?"), `Expected /result? prefix, got: ${url}`);
  });

  test("encodes Korean characters", () => {
    const url = buildResultUrl(COURSE);
    assert.ok(!url.includes("한강"), "Korean should be encoded");
    assert.ok(url.includes(encodeURIComponent("한강")));
  });

  test("includes all four params", () => {
    const url = buildResultUrl(COURSE);
    assert.ok(url.includes("place="));
    assert.ok(url.includes("food="));
    assert.ok(url.includes("transport="));
    assert.ok(url.includes("budget="));
  });

  test("includes base when provided", () => {
    const url = buildResultUrl(COURSE, "https://soragodong.vercel.app");
    assert.ok(url.startsWith("https://soragodong.vercel.app/result?"));
  });
});

describe("buildOgUrl", () => {
  test("produces a URL with /api/og path", () => {
    const url = buildOgUrl(COURSE);
    assert.ok(url.startsWith("/api/og?"), `Expected /api/og? prefix, got: ${url}`);
  });

  test("has same params as buildResultUrl (just different path)", () => {
    const resultParams = new URLSearchParams(buildResultUrl(COURSE).split("?")[1]);
    const ogParams = new URLSearchParams(buildOgUrl(COURSE).split("?")[1]);
    assert.equal(resultParams.get("place"), ogParams.get("place"));
    assert.equal(resultParams.get("food"), ogParams.get("food"));
    assert.equal(resultParams.get("transport"), ogParams.get("transport"));
    assert.equal(resultParams.get("budget"), ogParams.get("budget"));
  });
});

describe("parseCourseFromParams", () => {
  test("parses a valid URLSearchParams", () => {
    const url = buildResultUrl(COURSE);
    const params = new URLSearchParams(url.split("?")[1]);
    const course = parseCourseFromParams(params);
    assert.deepEqual(course, COURSE);
  });

  test("returns null when any field is missing", () => {
    assert.equal(parseCourseFromParams(new URLSearchParams("place=%ED%95%9C%EA%B0%95")), null);
    assert.equal(parseCourseFromParams(new URLSearchParams("")), null);
  });

  test("round-trips correctly for all unicode Korean values", () => {
    const params = new URLSearchParams(buildResultUrl(COURSE).split("?")[1]);
    const parsed = parseCourseFromParams(params);
    assert.equal(parsed.place, COURSE.place);
    assert.equal(parsed.food, COURSE.food);
    assert.equal(parsed.transport, COURSE.transport);
    assert.equal(parsed.budget, COURSE.budget);
  });
});
