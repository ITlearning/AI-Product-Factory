// 정적 페이지 · vercel.json — 검색 노출 막기와 주소가 어긋나지 않는지.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';

const read = (p) => readFileSync(new URL(`../${p}`, import.meta.url), 'utf8');

test('세 페이지 모두 noindex, 참조하는 파일이 이 폴더 안에 있다', () => {
  for (const page of ['feedback.html', 'admin.html', 'privacy.html']) {
    const html = read(page);
    assert.match(html, /<meta name="robots" content="noindex, nofollow">/, page);
    for (const [, ref] of html.matchAll(/(?:src|href)="\.\/([^"]+)"/g)) assert.ok(existsSync(new URL(`../${ref}`, import.meta.url)), `${page} → ${ref}`);
    assert.doesNotMatch(html, /\.\.\/Mongdol-ENFP-Web|manifest|serviceWorker/, '따로 배포 — ENFP 경로·PWA 없음');
  }
});

test('vercel.json — 확장자 없는 주소, / 는 /feedback 으로, 전부 noindex', () => {
  const v = JSON.parse(read('vercel.json'));
  assert.equal(v.cleanUrls, true);
  assert.deepEqual(v.redirects, [{ source: '/', destination: '/feedback', permanent: false }]);
  const all = v.headers.find((h) => h.source === '/(.*)');
  assert.ok(all.headers.some((h) => h.key === 'X-Robots-Tag' && /noindex/.test(h.value)));
  const privacy = v.headers.find((h) => h.source === '/privacy');
  assert.ok(privacy.headers.some((h) => h.key === 'Cache-Control' && /max-age=300/.test(h.value)), '처리방침은 짧게 캐시');
});

test('브라우저 쪽 쿼리 모양이 서버 zod 와 같다', async () => {
  const { FeedbackSchema } = await import('../api/_lib/feedback.js');
  const js = read('js/feedback.js');
  for (const name of ['v', 'b', 'd']) assert.match(js, new RegExp(`tag\\('${name}'`), name);
  assert.equal(FeedbackSchema.safeParse({ kind: 'etc', text: 'x', v: '1.1.1', b: '4', d: 'iPhone17,1' }).success, true);
  assert.equal(FeedbackSchema.safeParse({ kind: 'etc', text: 'x', d: 'iPad16,3' }).success, true);
});
