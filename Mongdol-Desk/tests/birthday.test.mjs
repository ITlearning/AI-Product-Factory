// /birthday — 고르기 규칙(사람마다 다르고 한 브라우저에선 같다), 원본 뜻풀이, 생일이 밖으로 나가지 않는지.
import { test } from 'node:test';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';

const read = (p) => readFileSync(new URL(`../${p}`, import.meta.url), 'utf8');
const source = JSON.parse(read('data/birthday-words.json'));
const bySource = new Map(source.map((w) => [w.w, w]));
const pick = vm.runInNewContext(read('js/birthday-pick.js') + ';birthdayPick');
const DAYS = []; for (let m = 1; m <= 12; m++) for (let d = 1; d <= new Date(2024, m, 0).getDate(); d++) DAYS.push([m, d]);
const SEEDS = Array.from({ length: 40 }, (_, i) => `seed-${i}`);

test('한 브라우저(seed)에선 다시 해도 같은 말, 같은 생일이어도 사람마다 다른 말', () => {
  for (const [m, d] of [[11, 24], [4, 4], [2, 29], [7, 10]]) {
    assert.deepEqual(pick(source, 'a', m, d), pick(source, 'a', m, d));
    const seen = new Set(SEEDS.map((s) => pick(source, s, m, d).w));
    assert.ok(seen.size >= 15, `${m}/${d} — 40명에 ${seen.size}가지`);
  }
});

test('대표 말은 그 달에 어울리는 말 — 한 브라우저에서 같은 달 다른 날짜끼리 겹치지 않는다', () => {
  for (const s of SEEDS.slice(0, 5)) {
    const byMonth = new Map();
    for (const [m, d] of DAYS) {
      const r = pick(source, s, m, d), src = bySource.get(r.w);
      assert.ok(src.months.includes(m), `${s} ${m}/${d} ${r.w}`);
      assert.equal(r.m, src.m);
      assert.equal(r.x.length, 2);
      assert.notEqual(r.x[0].w, r.w); assert.notEqual(r.x[1].w, r.w); assert.notEqual(r.x[0].w, r.x[1].w);
      const ws = byMonth.get(m) ?? new Set(); assert.ok(!ws.has(r.w), `${s} ${m}/${d} ${r.w} 겹침`); ws.add(r.w); byMonth.set(m, ws);
    }
  }
});

test('날짜가 정해진 말은 그 날에만, 그 날에서도 여럿 중 하나', () => {
  for (const [m, d, w] of [[1, 1, '해맞이'], [5, 5, '어린이날'], [5, 8, '어버이날'], [12, 31, '해넘이']]) {
    const got = SEEDS.map((s) => pick(source, s, m, d).w);
    assert.ok(got.includes(w), `${m}/${d} — ${w} 가 한 번도 안 나옴`);
    assert.ok(got.filter((g) => g !== w).length >= 20, `${m}/${d} — 거의 고정`);
  }
  for (const s of SEEDS.slice(0, 5)) for (const [m, d] of DAYS) {
    if (['0101', '0505', '0508', '1231'].includes(String(m).padStart(2, '0') + String(d).padStart(2, '0'))) continue;
    assert.ok(!['해맞이', '어린이날', '어버이날', '해넘이'].includes(pick(source, s, m, d).w), `${m}/${d}`);
  }
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
  assert.ok(sends.length >= 5);
  for (const a of sends) assert.match(a, /^'[a-z_$]+'$/, `send(${a}) — 이벤트 이름만`);
  assert.match(js, /location\.origin \+ '\/birthday\?utm_source=share'/);
  assert.match(html, /href="\/get\?utm_source=birthday/);
});

test('공유 — 글과 주소를 줄을 나눠 text 하나로, 미리보기는 생일 소개 이미지(예시 카드는 그 달의 말)', () => {
  const js = read('js/birthday.js');
  assert.match(js, /var text = '[^']+\\n' \+ url;/);
  assert.doesNotMatch(js, /navigator\.share\(\{[^}]*url:/, 'url 을 따로 넘기면 글 뒤에 붙는다');
  const html = read('birthday.html');
  assert.match(html, /og:image" content="https:\/\/mongdol-desk\.vercel\.app\/img\/og-birthday\.jpg"/);
  assert.ok(existsSync(new URL('../img/og-birthday.jpg', import.meta.url)));
  const og = read('tools/og-birthday.html');
  for (const [, m, d, w] of og.matchAll(/(\d+)월 (\d+)일의 우리말<\/div><div class="w">([^<]+)</g)) {
    assert.ok(bySource.get(w)?.months.includes(Number(m)), `${m}월 ${d}일 ${w}`);
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

test('열쇠는 브라우저에만 — localStorage 에 두고, 고르기 스크립트를 먼저 싣는다', () => {
  const js = read('js/birthday.js'), html = read('birthday.html');
  assert.match(js, /localStorage\.getItem\('mongdol-birthday-seed'\)/);
  assert.match(js, /birthdayPick\(t, seed, m, d\)/);
  assert.ok(html.indexOf('js/birthday-pick.js') < html.indexOf('js/birthday.js"'));
});

test('이미지로 저장 — 1080×1350 그림, 페이지 주소를 넣고, 파일 공유가 되면 시트로', () => {
  const js = read('js/birthday.js'), html = read('birthday.html');
  assert.match(html, /id="image">이미지로 저장</);
  assert.match(js, /var W = 1080, H = 1350/);
  assert.match(js, /mongdol-desk\.vercel\.app\/birthday/);
  assert.match(js, /navigator\.canShare\(\{ files: \[file\] \}\)/);
  assert.match(js, /send\('birthday_image'\)/);
});

test('Tabber 기기 표시 — ?internal=1 이면 localStorage 에 남기고 기록에 internal 을 붙인다(생일만 — /get 은 저장소를 안 쓴다고 처리방침에 약속)', () => {
  assert.doesNotMatch(read('get.html'), /mongdol-internal/);
  for (const f of ['js/birthday.js']) {
    const s = read(f);
    assert.match(s, /q\.get\('internal'\) === '1'\) localStorage\.setItem\('mongdol-internal', '1'\)/, f);
    assert.match(s, /if \(localStorage\.getItem\('mongdol-internal'\)\) base\.internal = true;/, f);
  }
});

test('안심 문구는 「알아보기」 바로 아래 — 생일·단어를 보내지 않고 누군지 알 수 없다', () => {
  const html = read('birthday.html');
  assert.match(html, /type="submit">알아보기<\/button>\n\s*<p class="bd-safe">생일과 나온 단어는 어디에도 보내지 않아요\./);
});

test('「어떤 기준으로 고르나요?」 — 그 달 말 몇 개 중에서 골랐는지 숫자가 맞다', () => {
  assert.match(read('birthday.html'), /<summary>어떤 기준으로 고르나요\?<\/summary>/);
  for (const [m, d] of [[4, 10], [11, 24], [5, 5]]) {
    // 날짜가 정해진 말은 제 날에만 후보다(5월 5일 후보에 어버이날은 없다).
    const DAY = { '0101': '해맞이', '0505': '어린이날', '0508': '어버이날', '1231': '해넘이' };
    const key = String(m).padStart(2, '0') + String(d).padStart(2, '0');
    const inMonth = source.filter((w) => w.months.includes(m) && (!Object.values(DAY).includes(w.w) || DAY[key] === w.w)).length;
    assert.equal(pick(source, 'x', m, d).pool, inMonth, `${m}/${d}`);
  }
});
