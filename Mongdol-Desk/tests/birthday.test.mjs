// /birthday — 생일 표가 앱 단어 목록과 어긋나지 않는지, 생일이 밖으로 나가지 않는지.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';

const read = (p) => readFileSync(new URL(`../${p}`, import.meta.url), 'utf8');
const table = JSON.parse(read('data/birthday.json'));
const source = JSON.parse(read('data/birthday-words.json'));
const bySource = new Map(source.map((w) => [w.w, w]));

test('366일(2월 29일 포함) 모두 서로 다른 말', () => {
  assert.equal(Object.keys(table).length, 366);
  assert.ok(table['0229']);
  assert.equal(new Set(Object.values(table).map((v) => v.w)).size, 366);
});

test('표의 말은 원본(birthday-words.json)의 말이고 뜻풀이도 같다 — 원본이 바뀌면 npm run build:birthday', () => {
  for (const [day, { w, m, x }] of Object.entries(table)) {
    assert.equal(bySource.get(w)?.m, m, `${day} ${w}`);
    for (const e of x) assert.equal(bySource.get(e.w)?.m, e.m, `${day} 곁말 ${e.w}`);
  }
});

test('대표 말은 모두 그 달에 어울리는 말 — 철 없는 말로 채운 날이 없다', () => {
  for (const [day, { w }] of Object.entries(table)) {
    assert.ok(bySource.get(w).months.includes(Number(day.slice(0, 2))), `${day} ${w}`);
  }
  for (const [day, w] of [['0101', '해맞이'], ['0505', '어린이날'], ['0508', '어버이날'], ['1231', '해넘이']]) assert.equal(table[day].w, w);
});

test('뜻풀이에 사전 표기(따옴표·어깨번호·괄호 한자)가 남지 않는다', () => {
  for (const w of source) assert.doesNotMatch(w.m, /[‘’「」(]/, w.w);
});

test('페이지 — noindex, 참조 파일이 있다, 생일을 보내지 않고 공유 주소에도 싣지 않는다', () => {
  const html = read('birthday.html');
  assert.match(html, /<meta name="robots" content="noindex, nofollow">/);
  for (const [, ref] of html.matchAll(/(?:src|href)="\.\/([^"]+)"/g)) assert.ok(existsSync(new URL(`../${ref}`, import.meta.url)), ref);
  const js = read('js/birthday.js');
  const sends = [...js.matchAll(/send\(([^)]*)\)/g)].map((m) => m[1]).filter((a) => a !== 'event');
  assert.ok(sends.length >= 4);
  for (const a of sends) assert.match(a, /^'[a-z_$]+'$/, `send(${a}) — 이벤트 이름만`);
  assert.match(js, /location\.origin \+ '\/birthday\?utm_source=share'/);
  assert.match(html, /href="\/get\?utm_source=birthday/);
});

test('공유 — 글과 주소를 줄을 나눠 text 하나로, 미리보기는 생일 소개 이미지(예시 카드는 표와 같다)', () => {
  const js = read('js/birthday.js');
  assert.match(js, /var text = '[^']+\\n' \+ url;/);
  assert.doesNotMatch(js, /navigator\.share\(\{[^}]*url:/, 'url 을 따로 넘기면 글 뒤에 붙는다');
  const html = read('birthday.html');
  assert.match(html, /og:image" content="https:\/\/mongdol-desk\.vercel\.app\/img\/og-birthday\.jpg"/);
  assert.ok(existsSync(new URL('../img/og-birthday.jpg', import.meta.url)));
  const og = read('tools/og-birthday.html');
  for (const [, m, d, w] of og.matchAll(/(\d+)월 (\d+)일의 우리말<\/div><div class="w">([^<]+)</g)) {
    assert.equal(table[String(m).padStart(2, '0') + String(d).padStart(2, '0')].w, w, `${m}월 ${d}일 ${w}`);
  }
});

test('앱으로 잇기 — 방금 본 말로 다리, 앱 화면, iPhone 아니면 인스타를 앞에, 움직임 줄이기 존중', () => {
  const html = read('birthday.html'), js = read('js/birthday.js'), css = read('styles.css');
  assert.match(html, /id="bridge"/);
  assert.match(html, /src="\.\/img\/get-phone\.jpg"/);
  assert.match(js, /if \(!IOS\)/);
  assert.match(js, /send\('birthday_insta_click'\)/);
  assert.match(css, /prefers-reduced-motion: reduce/);
  assert.match(css, /@keyframes bd-letter/);
});

test('곁말 — 날마다 두 개, 대표 말·서로와 겹치지 않고, 한 말은 세 날까지', () => {
  const mains = new Set(Object.values(table).map((v) => v.w)), uses = new Map();
  for (const [day, v] of Object.entries(table)) {
    assert.equal(v.x.length, 2, day);
    assert.notEqual(v.x[0].w, v.x[1].w, day);
    for (const x of v.x) {
      assert.ok(!mains.has(x.w), `${day} ${x.w} — 다른 날 대표 말`);
      uses.set(x.w, (uses.get(x.w) ?? 0) + 1);
    }
  }
  assert.ok(Math.max(...uses.values()) <= 3);
});
