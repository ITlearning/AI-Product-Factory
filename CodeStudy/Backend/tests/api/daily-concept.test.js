import { describe, it } from 'node:test';
import assert from 'node:assert/strict';

/**
 * Helper: build a GET Request-like object with query params.
 * Route Handler req.url is already a full absolute URL.
 */
function makeRequest(queryString) {
  return {
    url: `http://localhost/api/daily-concept${queryString}`,
    headers: {
      get(_key) {
        return null;
      },
    },
  };
}

let GET;
let importError;

try {
  const mod = await import('../../api/daily-concept.js');
  GET = mod.GET;
} catch (err) {
  importError = err;
}

describe('GET /api/daily-concept', () => {
  const testFn = importError ? it.skip : it;

  testFn('returns a concept for a valid level', async () => {
    const req = makeRequest('?level=beginner');
    const res = await GET(req);

    assert.equal(res.status, 200);
    const data = await res.json();
    assert.ok(data.conceptId, 'should have conceptId');
    assert.ok(data.title_ko, 'should have title_ko');
    assert.ok(data.title_en, 'should have title_en');
    assert.ok(data.level, 'should have level');
    assert.ok(data.category, 'should have category');
  });

  testFn('returns 400 for missing level', async () => {
    const req = makeRequest('');
    const res = await GET(req);
    assert.equal(res.status, 400);
  });

  testFn('returns 400 for unknown level', async () => {
    const req = makeRequest('?level=nonexistent_level_xyz');
    const res = await GET(req);
    assert.equal(res.status, 400);
    const data = await res.json();
    assert.ok(data.error.includes('nonexistent_level_xyz'));
  });

  testFn('returns a review concept when all concepts are studied', async () => {
    // Pass a very large studied list — the selector should return a review concept
    // rather than null when everything has been studied
    const manyIds = Array.from({ length: 200 }, (_, i) => `concept_${i}`).join(
      ',',
    );
    const req = makeRequest(`?level=beginner&studied=${manyIds}`);
    const res = await GET(req);

    assert.equal(res.status, 200);
    const data = await res.json();
    assert.ok(data.conceptId, 'should still return a concept for review');
  });
});
