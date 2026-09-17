/**
 * 시드 골든 테스트.
 *
 * 시드는 이 제품에서 콘텐츠가 아니라 **규범**이라(설계 → 시드 문서),
 * 스키마 제약을 어기거나 자기 제품의 PII 규칙에 걸리면 출시 당일 홈이 무너진다.
 * 그래서 `seed.json`을 회귀 테스트로 묶어둔다.
 */

import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import { validateSeed } from '../seed/validate.js';
import { detectPII, summarizePII } from '../src/moderation.js';
import { hashKey } from '../src/identity.js';
import { SEASONS, ERAS, currentSeason } from '../src/labels.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const seed = JSON.parse(readFileSync(join(__dirname, '../seed/seed.json'), 'utf8'));

test('시드가 스키마 제약을 전부 만족한다', () => {
  const { errors } = validateSeed(seed);
  assert.deepEqual(errors, [], `시드 검증 실패:\n${errors.join('\n')}`);
});

test('드라이런이 확정한 물량 — 곡 11개 · 기억 11편', () => {
  assert.equal(seed.songs.length, 11);
  assert.equal(seed.memories.length, 11);
});

test('모든 기억이 실재하는 곡을 가리킨다', () => {
  const refs = new Set(seed.songs.map((s) => s.ref));
  for (const m of seed.memories) {
    assert.ok(refs.has(m.song_ref), `${m.song_ref} 가 songs에 없다`);
  }
});

test('iTunes에 없던 곡 1개는 source=youtube로 남아 있다', () => {
  // 드라이런 실측: 20곡 중 1곡이 iTunes 카탈로그에 없었다(「그래 우리 함께」).
  // 이 경로가 사라지면 예능·인디·유통 끊긴 곡이 통째로 등록 불가가 된다.
  const yt = seed.songs.filter((s) => s.source === 'youtube');
  assert.equal(yt.length, 1);
  assert.equal(yt[0].title, '그래 우리 함께');
  assert.equal(yt[0].itunes_artist_id, null);
});

test('시드 본문이 제품의 PII 규칙을 통과한다', () => {
  for (const m of seed.memories) {
    assert.deepEqual(detectPII(m.body), [], `${m.song_ref} 본문에서 PII가 검출됐다`);
  }
});

test('라벨은 스키마 CHECK 안에 있고, 없어도 된다', () => {
  for (const m of seed.memories) {
    if (m.season != null) assert.ok(SEASONS.includes(m.season), `season ${m.season}`);
    if (m.era != null) assert.ok(ERAS.includes(m.era), `era ${m.era}`);
  }
  // 라벨이 안 붙는 글이 많은 게 정상 — 설계가 그렇게 정했다.
  const unlabelled = seed.memories.filter((m) => m.season == null).length;
  assert.ok(unlabelled > 0, '계절이 전부 붙어 있으면 시드가 설계와 다르게 다듬어진 것이다');
});

test('era 6개 — 군생활·대학 때가 실제 시드에 쓰인다', () => {
  // 스키마 초안의 5개(child,school,twenties,career,now)로는 이 두 편이 들어가지 않는다.
  const eras = new Set(seed.memories.map((m) => m.era).filter(Boolean));
  assert.ok(eras.has('military'), '「Credit」의 군생활이 빠졌다');
  assert.ok(eras.has('university'), '「골목길 어귀에서」·「나무」의 대학 때가 빠졌다');
});

test('시드 길이가 들쭉날쭉하다', () => {
  // 시드가 전부 비슷한 길이면 그 고름이 규범이 되어 사람들이 같은 모양의 글만 쓴다.
  const lens = seed.memories.map((m) => [...m.body].length);
  assert.ok(Math.min(...lens) < 100, `가장 짧은 글이 ${Math.min(...lens)}자 — 짧은 글이 없다`);
  assert.ok(Math.max(...lens) > 250, `가장 긴 글이 ${Math.max(...lens)}자 — 긴 글이 없다`);
});

test('PII 검출기 — 걸릴 것은 걸리고 억울한 건 안 걸린다', () => {
  assert.equal(detectPII('연락처는 010-1234-5678이야').length, 1);
  assert.equal(detectPII('01012345678로 연락 줘').length, 1);
  assert.equal(detectPII('me@example.com 으로 보내줘').length, 1);
  assert.equal(detectPII('계좌 110-123-456789 로 보내').length, 1);

  // 오탐 방지 — 여기서 억울하게 막히면 그 사람은 안 돌아온다.
  assert.deepEqual(detectPII('2014-03-15에 처음 들었다'), []);
  assert.deepEqual(detectPII('2002년 월드컵 때 들었던 노래'), []);
  assert.deepEqual(detectPII('1학년 2학기 때였다'), []);
});

test('PII 요약에 원문 조각이 새지 않는다', () => {
  const line = summarizePII(detectPII('010-1234-5678'));
  assert.ok(!line.includes('1234'), '요약에 원문이 들어가면 그게 곧 PII 로그다');
  assert.equal(line, '전화번호 1건');
});

test('hashKey는 서버에서만 계산되며 원본을 되돌릴 수 없다', () => {
  const h = hashKey('device-secret-key');
  assert.match(h, /^[0-9a-f]{64}$/);
  assert.equal(h, hashKey('device-secret-key'), '같은 키는 같은 해시');
  assert.notEqual(h, hashKey('device-secret-kex'));
  assert.throws(() => hashKey(''), TypeError);
  assert.throws(() => hashKey('x'.repeat(513)), TypeError);
});

test('현재 계절 — 북반구 기준', () => {
  assert.equal(currentSeason(new Date('2026-09-17')), 'autumn');
  assert.equal(currentSeason(new Date('2026-01-05')), 'winter');
  assert.equal(currentSeason(new Date('2026-04-01')), 'spring');
  assert.equal(currentSeason(new Date('2026-07-20')), 'summer');
});
