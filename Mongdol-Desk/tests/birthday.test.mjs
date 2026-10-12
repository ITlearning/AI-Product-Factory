// /birthday — 생일 표가 앱 단어 목록과 어긋나지 않는지, 생일이 밖으로 나가지 않는지.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';

const read = (p) => readFileSync(new URL(`../${p}`, import.meta.url), 'utf8');
const table = JSON.parse(read('data/birthday.json'));
const words = JSON.parse(read('../Color-Moments/Shared/Word/words.json'));

test('366일(2월 29일 포함) 모두 서로 다른 말', () => {
  assert.equal(Object.keys(table).length, 366);
  assert.ok(table['0229']);
  assert.equal(new Set(Object.values(table).map((v) => v.w)).size, 366);
});

test('표의 말은 앱 단어 목록에 살아 있는 말이고 뜻풀이도 같다', () => {
  const retired = new Set(words.retired);
  const live = new Map(words.words.filter((w) => !retired.has(w.id)).map((w) => [w.word, w.meaning]));
  for (const [day, { w, m }] of Object.entries(table)) {
    assert.ok(live.has(w), `${day} ${w} — 목록에 없거나 은퇴`);
    assert.equal(live.get(w), m, `${day} ${w} — 뜻풀이가 다르다(npm run build:birthday)`);
  }
});

test('철이 어긋나는 말이 없다 — 눈·얼음은 겨울 언저리에만, 더위는 여름 언저리에만', () => {
  for (const [day, { w }] of Object.entries(table)) {
    const m = Number(day.slice(0, 2));
    if (/함박눈|눈발|눈송이|고드름|얼음/.test(w)) assert.ok([11, 12, 1, 2, 3].includes(m), `${day} ${w}`);
    if (/더위/.test(w)) assert.ok([5, 6, 7, 8, 9].includes(m), `${day} ${w}`);
  }
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
