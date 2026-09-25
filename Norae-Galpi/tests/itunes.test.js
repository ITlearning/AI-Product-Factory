/**
 * 골든 테스트 — 2026-09-16 드라이런 20곡이 그대로 회귀 스위트가 된다.
 *
 * 입력과 기대값은 `docs/designs/norae-galpi-seed.md` 의 실측 표에서 왔고,
 * iTunes 응답은 `tests/fixtures/itunes-dryrun.json` 에 떠 두었다 — 테스트는 네트워크를 안 탄다.
 *
 * 여기서 지키는 회귀 케이스 두 개는 **실제로 터졌던 것**이다.
 *   - `L'Amour`(일반 아포스트로피) vs `L’Amour`(타이포그래픽)
 *   - 「노래방에서」가 `노래방` 때문에 MR로 오탐
 */

import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import { titleKey, looksLikeInstrumental, rankCandidates } from '../src/itunes.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const fixture = JSON.parse(
  readFileSync(join(__dirname, 'fixtures/itunes-dryrun.json'), 'utf8'),
);

test('titleKey — 드라이런 19곡의 실측 기대값', () => {
  const checked = [];
  for (const c of fixture.cases) {
    if (c.expectTrackId == null) continue; // iTunes에 없는 곡
    const hit = c.results.find((r) => r.trackId === c.expectTrackId);
    assert.ok(hit, `${c.q}: 기대한 trackId ${c.expectTrackId} 가 응답에 없다`);
    assert.equal(
      titleKey(hit.trackName),
      c.expectKey,
      `${c.q}: us 제목 "${hit.trackName}" 의 키가 다르다`,
    );
    checked.push(c.q);
  }
  assert.equal(checked.length, 19, `19곡을 봐야 하는데 ${checked.length}곡만 봤다`);
});

test('titleKey — 아포스트로피 두 종류가 같은 키가 된다', () => {
  // 실제로 터졌던 회귀. NFC는 ' 와 ’ 를 합치지 않으므로 기호 제거 단계까지 가야 만난다.
  assert.equal(titleKey("L'Amour, Les Baguettes, Paris"), 'lamourlesbaguettesparis');
  assert.equal(titleKey('L’Amour, Les Baguettes, Paris'), 'lamourlesbaguettesparis');
});

test('titleKey — 같은 아티스트의 Live·Inst·Remix는 원곡과 한 카드가 된다', () => {
  // 이건 의도다. "밤편지 라이브"를 들으며 생긴 기억도 "밤편지"의 기억이다.
  const base = titleKey('Through the Night');
  for (const variant of [
    'Through the Night (Live)',
    'Through the Night (Acoustic)',
    'Through the Night (Remix)',
    'Through the Night [MV]',
    'Through the Night (feat. Someone)',
    'Through the Night - Remastered 2011',
    'Through the Night - Radio Edit',
  ]) {
    assert.equal(titleKey(variant), base, `${variant} 가 원곡과 갈렸다`);
  }
});

test('titleKey — 제목 안의 붙임표는 꼬리표가 아니다', () => {
  // 공백으로 둘러싸인 하이픈만 꼬리표로 본다.
  assert.equal(titleKey('Spider-Man'), 'spiderman');
  assert.equal(titleKey('e-Motion'), 'emotion');
});

test('titleKey — 키가 비면 원본으로 되돌아간다', () => {
  // 키가 빈 문자열이면 UNIQUE (artist_id, title_key) 가 전부 충돌한다.
  assert.equal(titleKey('(Instrumental)'), '(Instrumental)');
  assert.equal(titleKey('...'), '...');
  assert.notEqual(titleKey('(A)'), titleKey('(B)'));
});

test('titleKey — NFC 정규화', () => {
  // 한글 조합형(NFD)과 완성형(NFC)이 같은 키가 돼야 한다.
  const nfd = '그대라는 시'.normalize('NFD');
  assert.notEqual(nfd, '그대라는 시'); // 입력이 실제로 다른지 먼저 확인
  assert.equal(titleKey(nfd), titleKey('그대라는 시'));
});

test('MR 검사는 괄호 안으로 한정한다 — 「노래방에서」오탐 방지', () => {
  // 제목 전체를 검사하면 `노래방` 때문에 오탐된다. 드라이런에서 실제로 터졌다.
  assert.equal(looksLikeInstrumental('노래방에서'), false);
  assert.equal(looksLikeInstrumental('Karaoke'), false);
  assert.equal(looksLikeInstrumental('Minstrel'), false, 'inst 가 단어 안에 있을 뿐이다');

  assert.equal(looksLikeInstrumental('그라데이션 (Inst.)'), true);
  assert.equal(looksLikeInstrumental('그라데이션 (B 남자키) [MR]'), true);
  assert.equal(looksLikeInstrumental('나무 (Instrumental)'), true);
  assert.equal(looksLikeInstrumental('우연히 잠시라도 (여자키 MR)'), true);
});

test('rankCandidates — 드라이런에서 원곡이 1순위로 올라온다', () => {
  const misses = [];
  let checked = 0;

  for (const c of fixture.cases) {
    if (c.expectTrackId == null) continue;
    const ranked = rankCandidates(c.q, c.results);
    checked += 1;
    if (ranked[0]?.trackId !== c.expectTrackId) {
      const got = ranked[0];
      misses.push(`${c.q} → ${got?.krTrackName ?? got?.trackName} / ${got?.krArtistName ?? got?.artistName}`);
    }
  }

  // 드라이런 실측은 20곡 중 19곡(95%)에서 원곡이 맨 위였다. 그 수준을 내리지 않는다.
  assert.equal(misses.length, 0, `원곡이 1순위가 아닌 곡:\n${misses.join('\n')}\n(확인 ${checked}곡)`);
});

test('rankCandidates — MR·Inst 가 섞인 곡에서도 원곡이 위다', () => {
  // 드라이런에서 실제로 섞여 들어온 곡들. 그라데이션 3개, 우연히 잠시라도 2개, 나무 2개.
  const mixed = fixture.cases.filter((c) =>
    c.results.some((r) => looksLikeInstrumental(r.krTrackName ?? r.trackName)),
  );
  assert.ok(mixed.length > 0, '픽스처에 MR 섞인 곡이 하나도 없다 — 픽스처가 낡았다');

  for (const c of mixed) {
    const ranked = rankCandidates(c.q, c.results);
    const topIsMr = looksLikeInstrumental(ranked[0].krTrackName ?? ranked[0].trackName);
    assert.equal(topIsMr, false, `${c.q}: 맨 위가 반주 트랙이다`);
  }
});

test('rankCandidates — 아티스트는 필터가 아니라 가중치다', () => {
  // `프로미스나인` vs `fromis_9` 는 kr lookup 에서도 안 맞는다.
  // 제목이 맞으면 후보에 남고, 아티스트가 맞으면 위로 올라간다.
  const ranked = rankCandidates('DM 프로미스나인', [
    { trackId: 1, trackName: 'DM', artistName: 'fromis_9', krTrackName: 'DM', krArtistName: 'fromis_9' },
    { trackId: 2, trackName: 'Other', artistName: 'fromis_9', krTrackName: '다른곡', krArtistName: 'fromis_9' },
  ]);
  assert.equal(ranked.length, 2, '아티스트가 안 맞는다고 후보가 떨어졌다');
  assert.equal(ranked[0].trackId, 1);
});

test('rankCandidates — 원본 배열을 바꾸지 않는다', () => {
  const input = [
    { trackId: 1, trackName: 'B', artistName: 'x' },
    { trackId: 2, trackName: 'A', artistName: 'x' },
  ];
  const before = input.map((r) => r.trackId);
  rankCandidates('A', input);
  assert.deepEqual(input.map((r) => r.trackId), before);
});

test('iTunes에 없는 곡은 그럴듯한 오답을 돌려준다 — 자동 선택이 위험한 이유', () => {
  // 「그래 우리 함께」(무한도전)는 iTunes 카탈로그에 없다. 그런데 빈손으로 돌아오지 않는다.
  // 사용자가 확인 없이 넘어가면 그 기억이 엉뚱한 곡에 붙고, 그 곡의 첫 사람이면
  // 유튜브 영상까지 그쪽으로 고정된다. 그래서 ① 화면에 자동 선택이 없다.
  const c = fixture.cases.find((x) => x.expectTrackId === null);
  assert.ok(c, '픽스처에 iTunes 미수록 곡 케이스가 없다');
  if (c.results.length > 0) {
    const top = rankCandidates(c.q, c.results)[0];
    assert.notEqual(
      top.krTrackName ?? top.trackName,
      '그래 우리 함께',
      '이 곡이 iTunes에 생겼다면 픽스처와 설계를 다시 봐야 한다',
    );
  }
});
