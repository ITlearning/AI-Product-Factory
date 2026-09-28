/**
 * 신원·DB 공통 모듈. 로그인이 없는 제품이라 여기가 곧 보안 경계다.
 */

import test from 'node:test';
import assert from 'node:assert/strict';

import { hashKey, requireKey, newDeviceKey } from '../src/identity.js';
import { getSql, requireSql, _setSql } from '../src/db.js';

test('requireKey — 키를 해시로 바꿔 돌려준다', () => {
  const key = newDeviceKey();
  assert.equal(requireKey({ deviceKey: key }), hashKey(key));
});

test('requireKey — 원본 키가 반환값에도 에러 메시지에도 안 남는다', () => {
  const key = 'SECRET-DEVICE-KEY-abcdef';
  const out = requireKey({ deviceKey: key });
  assert.ok(!out.includes('SECRET'), '해시에 원본이 섞였다');
  assert.match(out, /^[0-9a-f]{64}$/);

  // 잘못된 값이 와도 그 값을 메시지에 싣지 않는다 — 그 값이 곧 키다.
  for (const bad of [undefined, null, '', 123, {}, [], '   ', 'x'.repeat(600)]) {
    try {
      requireKey({ deviceKey: bad });
      assert.fail(`${JSON.stringify(bad)} 가 통과했다`);
    } catch (err) {
      assert.equal(err.status, 400);
      // 빈 문자열은 includes 가 항상 참이라 단언이 성립하지 않는다. 실제로 샐 수 있는 값만 본다.
      const shown = String(bad);
      if (shown.length >= 3) {
        assert.ok(!err.message.includes(shown), `에러 메시지에 입력값이 실렸다: ${err.message}`);
      }
    }
  }
  assert.throws(() => requireKey(undefined), /기기 키/);
});

test('newDeviceKey — 매번 다르고 URL에 안전하다', () => {
  const keys = new Set();
  for (let i = 0; i < 200; i++) keys.add(newDeviceKey());
  assert.equal(keys.size, 200, '키가 겹쳤다');
  for (const k of keys) assert.match(k, /^[A-Za-z0-9_-]+$/);
});

test('hashKey — 클라이언트가 보낸 해시를 그대로 쓰면 안 되는 이유', () => {
  // 서버에서 해싱하므로 DB에 저장된 해시로는 요청을 만들 수 없다.
  // 클라이언트 해싱이면 저장된 해시가 곧 bearer token 이 되어,
  // DB 유출 한 번에 전체 사용자의 삭제권이 털린다.
  const stored = hashKey('real-key');
  assert.notEqual(hashKey(stored), stored, '해시를 다시 해싱한 값이 원래 해시와 같다');
});

test('db — DATABASE_URL 이 없으면 getSql 은 null, requireSql 은 던진다', () => {
  const saved = process.env.DATABASE_URL;
  try {
    delete process.env.DATABASE_URL;
    _setSql(null);
    assert.equal(getSql(), null);
    assert.throws(() => requireSql(), /DATABASE_URL/);
  } finally {
    if (saved === undefined) delete process.env.DATABASE_URL;
    else process.env.DATABASE_URL = saved;
    _setSql(null);
  }
});

test('db — 클라이언트를 한 번만 만들고 재사용한다', () => {
  const fake = () => {};
  _setSql(fake);
  assert.equal(getSql(), fake);
  assert.equal(getSql(), fake, '호출할 때마다 새로 만들고 있다');
  _setSql(null);
});
