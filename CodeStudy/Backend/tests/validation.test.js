import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { validateTutorRequest } from '../src/validation.js';

describe('validateTutorRequest', () => {
  it('returns valid for a correct request', () => {
    const result = validateTutorRequest({
      messages: [{ role: 'user', content: 'Hello' }],
      conceptId: 'swift-optionals',
      sessionId: 'sess-123',
      userProfile: { level: 'beginner', language: 'ko' },
    });
    assert.deepStrictEqual(result, { valid: true });
  });

  it('rejects null body', () => {
    const result = validateTutorRequest(null);
    assert.strictEqual(result.valid, false);
    assert.ok(result.error.includes('JSON object'));
  });

  it('rejects undefined body', () => {
    const result = validateTutorRequest(undefined);
    assert.strictEqual(result.valid, false);
  });

  it('rejects when messages is not an array', () => {
    const result = validateTutorRequest({
      messages: 'not-array',
      conceptId: 'swift-optionals',
      sessionId: 'sess-123',
      userProfile: { level: 'beginner', language: 'ko' },
    });
    assert.strictEqual(result.valid, false);
    assert.ok(result.error.includes('messages'));
  });

  it('rejects when messages is missing', () => {
    const result = validateTutorRequest({
      conceptId: 'swift-optionals',
      sessionId: 'sess-123',
      userProfile: { level: 'beginner', language: 'ko' },
    });
    assert.strictEqual(result.valid, false);
  });

  it('rejects empty conceptId', () => {
    const result = validateTutorRequest({
      messages: [],
      conceptId: '',
      sessionId: 'sess-123',
      userProfile: { level: 'beginner', language: 'ko' },
    });
    assert.strictEqual(result.valid, false);
    assert.ok(result.error.includes('conceptId'));
  });

  it('rejects whitespace-only conceptId', () => {
    const result = validateTutorRequest({
      messages: [],
      conceptId: '   ',
      sessionId: 'sess-123',
      userProfile: { level: 'beginner', language: 'ko' },
    });
    assert.strictEqual(result.valid, false);
  });

  it('rejects missing sessionId', () => {
    const result = validateTutorRequest({
      messages: [],
      conceptId: 'swift-optionals',
      userProfile: { level: 'beginner', language: 'ko' },
    });
    assert.strictEqual(result.valid, false);
    assert.ok(result.error.includes('sessionId'));
  });

  it('rejects missing userProfile', () => {
    const result = validateTutorRequest({
      messages: [],
      conceptId: 'swift-optionals',
      sessionId: 'sess-123',
    });
    assert.strictEqual(result.valid, false);
    assert.ok(result.error.includes('userProfile'));
  });

  it('rejects invalid level', () => {
    const result = validateTutorRequest({
      messages: [],
      conceptId: 'swift-optionals',
      sessionId: 'sess-123',
      userProfile: { level: 'expert', language: 'ko' },
    });
    assert.strictEqual(result.valid, false);
    assert.ok(result.error.includes('level'));
  });

  it('rejects invalid language', () => {
    const result = validateTutorRequest({
      messages: [],
      conceptId: 'swift-optionals',
      sessionId: 'sess-123',
      userProfile: { level: 'beginner', language: 'fr' },
    });
    assert.strictEqual(result.valid, false);
    assert.ok(result.error.includes('language'));
  });

  it('accepts all valid levels', () => {
    for (const level of ['beginner', 'basic', 'intermediate', 'advanced']) {
      const result = validateTutorRequest({
        messages: [],
        conceptId: 'swift-optionals',
        sessionId: 'sess-123',
        userProfile: { level, language: 'en' },
      });
      assert.deepStrictEqual(result, { valid: true }, `level=${level} should be valid`);
    }
  });

  it('accepts empty messages array', () => {
    const result = validateTutorRequest({
      messages: [],
      conceptId: 'swift-optionals',
      sessionId: 'sess-123',
      userProfile: { level: 'beginner', language: 'ko' },
    });
    assert.deepStrictEqual(result, { valid: true });
  });
});
