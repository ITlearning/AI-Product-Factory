/**
 * logger.test.js — Cycle 2 신규.
 *
 * 검증 항목:
 *   1. Neon INSERT happy path — sql template tag가 호출되고 console.log 폴백은 안 일어남
 *   2. Neon 실패 → console.log fallback (regression) — Stage 1 동작 보존
 *
 * Test framework: node:test (package.json의 `test` 스크립트와 일치).
 */

import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { logConversation, _setSqlClient } from '../src/logger.js';

const SAMPLE_ENTRY = {
  event: 'turn',
  userId: 'user-abc',
  sessionId: 'sess-123',
  conceptId: 'swift-variables',
  turnIndex: 0,
  userInput: '변수가 뭐예요?',
  aiOutput: '변수란 값을 저장하는 공간입니다.',
  mastered: false,
  model: 'openai/gpt-4.1-mini',
  provider: 'openrouter',
  latencyMs: 1234,
  level: 'beginner',
  language: 'ko',
};

/**
 * console.log 캡쳐 헬퍼 — 테스트 동안 호출 인자 누적.
 *
 * @returns {{ logs: string[], restore: Function }}
 */
function captureConsole() {
  const logs = [];
  const original = console.log;
  console.log = (...args) => {
    logs.push(args.join(' '));
  };
  return {
    logs,
    restore: () => {
      console.log = original;
    },
  };
}

/**
 * Mock neon SQL client — template tag 함수 형태.
 * 호출 인자(strings, params)를 calls 배열에 누적.
 *
 * @param {object} [opts]
 * @param {boolean} [opts.shouldThrow=false] - true면 에러 throw
 * @param {string} [opts.errorMessage='neon down'] - throw할 에러 메시지
 * @returns {Function & { calls: Array }}
 */
function makeMockSql({ shouldThrow = false, errorMessage = 'neon down' } = {}) {
  const calls = [];
  const fn = async (strings, ...params) => {
    calls.push({ strings: Array.from(strings), params });
    if (shouldThrow) {
      throw new Error(errorMessage);
    }
    return [{ id: 1 }];
  };
  fn.calls = calls;
  return fn;
}

describe('logConversation', () => {
  let cap;

  beforeEach(() => {
    cap = captureConsole();
  });

  afterEach(() => {
    cap.restore();
    _setSqlClient(null);
  });

  it('Neon INSERT 성공 — sql template tag 1회 호출, console.log 폴백 없음', async () => {
    const mockSql = makeMockSql({ shouldThrow: false });
    _setSqlClient(mockSql);

    await logConversation(SAMPLE_ENTRY);

    // SQL 1회 호출
    assert.equal(mockSql.calls.length, 1, 'SQL should be called exactly once');

    const { strings, params } = mockSql.calls[0];

    // INSERT 문법 확인 (template literal의 정적 부분에 INSERT INTO가 있어야)
    const joined = strings.join('');
    assert.match(joined, /INSERT INTO codestudy_log/);
    assert.match(joined, /VALUES/);

    // 파라미터 바인딩 — 핵심 필드가 제대로 들어갔는지
    assert.equal(params[0], 'user-abc', 'user_id param');
    assert.equal(params[1], 'sess-123', 'session_id param');
    assert.equal(params[2], 'swift-variables', 'concept_id param');
    assert.equal(params[3], 'turn', 'event param');
    assert.equal(params[7], 'openai/gpt-4.1-mini', 'model param');

    // raw JSONB는 문자열로 직렬화된 entry 전체 (10번째 = index 9)
    const rawStr = params[9];
    assert.equal(typeof rawStr, 'string', 'raw should be JSON string');
    const parsed = JSON.parse(rawStr);
    assert.equal(parsed.userInput, '변수가 뭐예요?');
    assert.equal(parsed.aiOutput, '변수란 값을 저장하는 공간입니다.');
    assert.ok(parsed.ts, 'ts should be auto-added');

    // console.log fallback이 일어나지 않아야 — codestudy.log tag 라인이 없어야 함
    const fallbackLines = cap.logs.filter((l) => l.startsWith('codestudy.log '));
    assert.equal(
      fallbackLines.length,
      0,
      'console.log fallback should not fire on success',
    );
  });

  it('Neon 실패 → console.log fallback (regression) — 예외 미전파', async () => {
    const mockSql = makeMockSql({
      shouldThrow: true,
      errorMessage: 'connection timeout',
    });
    _setSqlClient(mockSql);

    // 호출이 throw하지 않아야 (regression: Stage 1 fire-and-forget 호환)
    await assert.doesNotReject(() => logConversation(SAMPLE_ENTRY));

    // SQL 호출은 1회 (그리고 실패)
    assert.equal(mockSql.calls.length, 1);

    // console.log fallback 발동 — codestudy.log 태그로 entry 출력
    const fallbackLines = cap.logs.filter((l) =>
      l.startsWith('codestudy.log '),
    );
    assert.equal(
      fallbackLines.length,
      1,
      'console.log fallback should fire exactly once',
    );

    // fallback line은 원본 entry를 JSON으로 포함해야
    const payload = fallbackLines[0].slice('codestudy.log '.length);
    const parsed = JSON.parse(payload);
    assert.equal(parsed.event, 'turn');
    assert.equal(parsed.userId, 'user-abc');
    assert.equal(parsed.sessionId, 'sess-123');
    assert.equal(parsed.userInput, '변수가 뭐예요?');
    assert.ok(parsed.ts, 'ts should be present in fallback');

    // 디버깅용 .error 라인도 1회 (선택적 검증)
    const errorLines = cap.logs.filter((l) =>
      l.startsWith('codestudy.log.error '),
    );
    assert.equal(
      errorLines.length,
      1,
      'error detail line should also be logged',
    );
  });

  it('DATABASE_URL 미설정 → console.log fallback (Stage 1 동작 보존)', async () => {
    // _setSqlClient(null) + DATABASE_URL 없는 상태 흉내
    _setSqlClient(null);
    const originalDbUrl = process.env.DATABASE_URL;
    delete process.env.DATABASE_URL;

    try {
      await logConversation(SAMPLE_ENTRY);

      const fallbackLines = cap.logs.filter((l) =>
        l.startsWith('codestudy.log '),
      );
      assert.equal(fallbackLines.length, 1);
    } finally {
      if (originalDbUrl !== undefined) {
        process.env.DATABASE_URL = originalDbUrl;
      }
    }
  });
});
