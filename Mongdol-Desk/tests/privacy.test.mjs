// /privacy — 앱 원본(Color-Moments/PRIVACY.md)과 커밋된 privacy.html 이 어긋나지 않는지, 그리고 작은 md 변환기.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { SOURCE, TARGET, renderPage, mdToHtml, inline, resolveHref, esc } from '../tools/build-privacy.mjs';

test('privacy.html 이 지금 PRIVACY.md 로 만든 것과 같다', () => {
  const want = renderPage(readFileSync(SOURCE, 'utf8'));
  const have = readFileSync(TARGET, 'utf8');
  assert.ok(have === want, 'Color-Moments/PRIVACY.md 가 바뀌었는데 privacy.html 을 다시 만들지 않았다 → `cd Mongdol-Desk && npm run build:privacy` 후 privacy.html 을 커밋하고 배포할 것');
});

test('이스케이프 — 글·코드·표·링크 글자·주소 모두', () => {
  assert.equal(esc(`<a href="x">'&'</a>`), '&lt;a href=&quot;x&quot;&gt;&#39;&amp;&#39;&lt;/a&gt;');
  assert.equal(inline('1 < 2 & <script>alert(1)</script>'), '1 &lt; 2 &amp; &lt;script&gt;alert(1)&lt;/script&gt;');
  assert.equal(inline('`<b>`'), '<code>&lt;b&gt;</code>');
  assert.equal(inline('**<i>**'), '<strong>&lt;i&gt;</strong>');
  assert.equal(inline('[<x>](https://a.example/?q="1"&r=2)'), '<a href="https://a.example/?q=&quot;1&quot;&amp;r=2">&lt;x&gt;</a>');
  const { body } = mdToHtml('| a<b |\n|---|\n| <img src=x onerror=alert(1)> |');
  assert.doesNotMatch(body, /<img/);
  assert.match(body, /&lt;img src=x onerror=alert\(1\)&gt;/);
});

test('링크 — [글](주소), 맨 주소, 위험한 스킴, 자기 자신·상대 링크', () => {
  assert.equal(inline('[Apple](https://www.apple.com/kr/legal/privacy/)이'), '<a href="https://www.apple.com/kr/legal/privacy/">Apple</a>이');
  assert.equal(inline('문의: https://github.com/x/y/issues.'), '문의: <a href="https://github.com/x/y/issues">https://github.com/x/y/issues</a>.');
  assert.doesNotMatch(inline('[클릭](javascript:alert(1))'), /<a /);
  assert.doesNotMatch(inline('[클릭](data:text/html,x)'), /<a /);
  assert.equal(inline('[링크 https://a.example](https://b.example)'), '<a href="https://b.example">링크 https://a.example</a>', '링크 글 안에서 또 링크를 만들지 않는다');
  assert.equal(resolveHref('https://github.com/ITlearning/AI-Product-Factory/blob/main/Color-Moments/PRIVACY.md'), '/privacy');
  assert.equal(resolveHref('https://raw.githubusercontent.com/ITlearning/AI-Product-Factory/main/Color-Moments/PRIVACY.md#5'), '/privacy#5');
  assert.equal(resolveHref('./PRIVACY.md'), '/privacy');
  assert.equal(resolveHref('#1-수집하지-않는-것'), '#1-수집하지-않는-것');
  assert.equal(resolveHref('DESIGN.md'), 'https://github.com/ITlearning/AI-Product-Factory/blob/main/Color-Moments/DESIGN.md');
  assert.equal(resolveHref('mailto:a@b.c'), 'mailto:a@b.c');
});

test('제목·문단·목록 — 맨 처음 # 은 페이지 머리로 빠진다', () => {
  const { title, body } = mdToHtml('# 몽돌 개인정보 처리방침\n\n시행일: 오늘\n둘째 줄\n\n## 1. 하나\n\n- **가**: 하나\n- 둘\n\n### 작은 제목\n\n# 또 큰 제목');
  assert.equal(title, '몽돌 개인정보 처리방침');
  assert.equal(body, [
    '<p>시행일: 오늘\n둘째 줄</p>',
    '<h2>1. 하나</h2>',
    '<ul>\n<li><strong>가</strong>: 하나</li>\n<li>둘</li>\n</ul>',
    '<h3>작은 제목</h3>',
    '<h2>또 큰 제목</h2>',
  ].join('\n'));
});

test('표 — 머리·몸, 가로 스크롤 감싸개, 칸이 모자라면 빈칸', () => {
  const { body } = mdToHtml('| 권한 | 쓰는 곳 |\n|---|:---:|\n| 카메라 | **찍을 때** |\n| 위치 |\n\n뒤 문단');
  assert.equal(body, [
    '<div class="table-wrap"><table>',
    '<thead><tr><th scope="col">권한</th><th scope="col">쓰는 곳</th></tr></thead>',
    '<tbody><tr><td>카메라</td><td><strong>찍을 때</strong></td></tr>\n<tr><td>위치</td><td></td></tr></tbody>',
    '</table></div>',
    '<p>뒤 문단</p>',
  ].join('\n'));
});

test('만든 페이지 — 머리·건의하기 링크·noindex, 원본의 표와 링크가 들어 있다', () => {
  const html = readFileSync(TARGET, 'utf8');
  assert.match(html, /<h1 class="doc-title">개인정보 처리방침<\/h1>/);
  assert.match(html, /<a href="\/feedback">건의하기<\/a>/);
  assert.match(html, /<meta name="robots" content="noindex, nofollow">/);
  assert.match(html, /<div class="table-wrap"><table>/);
  assert.match(html, /<a href="https:\/\/www\.apple\.com\/kr\/legal\/privacy\/">/);
  assert.doesNotMatch(html, /\*\*|\]\(/, 'md 문법이 그대로 새어 나오지 않는다');
});
