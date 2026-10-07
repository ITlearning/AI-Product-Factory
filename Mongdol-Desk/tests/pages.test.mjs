// 정적 페이지 · vercel.json — 검색 노출 막기와 주소가 어긋나지 않는지.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';

const read = (p) => readFileSync(new URL(`../${p}`, import.meta.url), 'utf8');

test('모든 페이지 noindex, 참조하는 파일이 이 폴더 안에 있다', () => {
  for (const page of ['feedback.html', 'admin.html', 'privacy.html', 'support.html']) {
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

test('/support — 건의하기·처리방침으로 가는 링크, 가리키는 페이지가 있다', () => {
  const html = read('support.html');
  assert.match(html, /<h1 class="doc-title">지원<\/h1>/);
  for (const [path, file] of [['/feedback', 'feedback.html'], ['/privacy', 'privacy.html']]) {
    assert.match(html, new RegExp(`href="${path}"`), path);
    assert.ok(existsSync(new URL(`../${file}`, import.meta.url)), file);
  }
  assert.match(html, /viewport-fit=cover/);
});

test('/feedback?app=1 — 그리기 전에 html.in-app, 머리 숨김·번짐 끔·아래 여백은 그 아래에서만', () => {
  const html = read('feedback.html');
  assert.match(html, /<meta name="viewport" content="[^"]*viewport-fit=cover/);
  const head = html.slice(0, html.indexOf('</head>'));
  assert.match(head, /classList\.add\('in-app'\)/, 'head 안에서 붙인다(깜빡임 없게)');
  assert.match(html, /class="wordmark page-head"/);
  const css = read('styles.css');
  assert.match(css, /\.in-app body::before \{ display: none; \}/);
  assert.match(css, /\.in-app \.page-head \{ display: none; \}/);
  assert.match(html, /<img class="done-pebble" src="\.\/img\/pebble\.jpg" width="150" height="150"/);
  assert.match(css, /\.done-pebble \{[^}]*aspect-ratio: 1; object-fit: contain;[^}]*mask-image: radial-gradient/, '돌은 1:1 + 둥근 마스크');
  assert.match(css, /\.in-app \.page \{[^}]*padding-bottom: calc\(var\(--safe-b\) \+ 4\d+px\)/);
});
