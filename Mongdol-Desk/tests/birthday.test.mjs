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
  const calls = js.split('\n').filter((l) => /\bsend\(/.test(l) && !/function send\(/.test(l));
  assert.ok(calls.length >= 8);
  for (const l of calls) {
    assert.match(l, /send\('[a-z_$]+'(\)|, \{ (via|where): |, Object\.assign\(\{$)/, `이벤트 이름 + via/where 만: ${l.trim()}`);
    assert.doesNotMatch(l, /send\([^;]*\b(last|w\.w|w\.m|month\.value|day\.value|seed)\b/, `생일·단어·열쇠를 싣지 않는다: ${l.trim()}`);
  }
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
  assert.match(js, /navigator\.canShare\({ files: \[file\] }\)/);
  assert.match(js, /send\('birthday_image', \{ via: 'share' \}\)/);
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

test('다리 문장 — 받침 있으면 「이었어요」, 없으면 「였어요」', () => {
  const js = read('js/birthday.js');
  const m = js.match(/var end = w\.w\.charCodeAt\(w\.w\.length - 1\), batchim = ([^;]+);/);
  assert.ok(m);
  const tail = (word) => { const w = { w: word }; const end = w.w.charCodeAt(w.w.length - 1); return eval(m[1]) ? '이었어요.' : '였어요.'; };
  assert.equal(tail('갈대꽃'), '이었어요.');
  assert.equal(tail('억새밭'), '이었어요.');
  assert.equal(tail('진달래'), '였어요.');
  assert.equal(tail('노랑나비'), '였어요.');
});

test('이미지 저장 — 결과가 뜰 때 미리 만들고, 시트가 안 되거나 실패하면(취소 빼고) 그림을 띄워 길게 눌러 저장', () => {
  const js = read('js/birthday.js'), html = read('birthday.html');
  assert.match(js, /prepareImage\(last\);/);
  assert.match(js, /if \(err && err\.name === 'AbortError'\) return;/);
  assert.match(js, /if \(mobile\) \{ send\('birthday_image', \{ via: 'sheet' \}\); showSheet\(url\); return; \}/);
  assert.doesNotMatch(js, /createObjectURL/, 'blob 내려받기는 앱 안 브라우저에서 「지원하지 않는 형식」');
  assert.match(html, /<div class="bd-sheet" id="sheet" hidden>/);
  assert.match(html, /id="sheetSave" hidden/);
});

test('결과 데이터(last)는 한 곳에만 — 다른 함수에서 var last 로 다시 선언하면 이미지 저장이 멈춘다', () => {
  const js = read('js/birthday.js');
  assert.equal((js.match(/var last\b/g) || []).length, 1);
});

test('인스타 버튼 — 앱 내장 브라우저(인스타·스레드·카톡·페북)에서는 인스타 앱을 직접 열고, 안 열리면 웹으로', () => {
  const js = read('js/birthday.js');
  const re = new RegExp(js.match(/var inApp = \/(.+)\/\.test\(ua\);/)[1]);
  for (const ua of ['Mozilla/5.0 (iPhone) Instagram 300.0', 'Mozilla/5.0 (iPhone) Barcelona 300.0', 'Mozilla/5.0 (iPhone) KAKAOTALK 10.0', 'Mozilla/5.0 (iPhone) [FBAN/FBIOS;FBAV/400]']) assert.ok(re.test(ua), ua);
  for (const ua of ['Mozilla/5.0 (iPhone) Version/18.0 Mobile/15E148 Safari/604.1', 'Mozilla/5.0 (Linux; Android 14) Chrome/126 Mobile Safari/537.36']) assert.ok(!re.test(ua), ua);
  assert.match(js, /'instagram:\/\/user\?username=' \+ INSTA/);
  assert.match(js, /intent:\/\/instagram\.com\/_u\/' \+ INSTA \+ '\/#Intent;package=com\.instagram\.android;scheme=https;S\.browser_fallback_url=/);
  assert.match(js, /setTimeout\(function \(\) \{ if \(!left && !document\.hidden\) location\.href = web; \}, 1200\)/);
});

test('고장 기록 — 어디서·오류 이름·메시지·스택·앱 종류를 자세히, 이미지 저장은 방식(via)을 함께', () => {
  const js = read('js/birthday.js');
  for (const w of ['page', 'promise', 'data', 'share', 'image', 'draw', 'canshare', 'font']) assert.match(js, new RegExp(`report\\('${w}'`), w);
  for (const k of ['error_name', 'error_message', 'error_stack', 'can_share', 'image_ready']) assert.match(js, new RegExp(`${k}:`), k);
  assert.match(js, /browser_app: \/KAKAOTALK\//);
  for (const v of ['share', 'sheet', 'download']) assert.match(js, new RegExp(`send\\('birthday_image', \\{ via: '${v}' \\}\\)`), v);
  const reports = js.split('\n').filter((l) => /\breport\(/.test(l) && !/function report\(/.test(l));
  for (const l of reports) assert.doesNotMatch(l.slice(l.indexOf('report(')), /\b(last|w\.w|w\.m|month\.value|day\.value|seed)\b/, `생일·단어·열쇠를 싣지 않는다: ${l.trim()}`);
});

test('이미지는 toDataURL 하나로 — toBlob(일부 앱 안 브라우저에서 null) 안 쓰고, 글꼴은 3초 상한', () => {
  const js = read('js/birthday.js');
  assert.doesNotMatch(js, /\.toBlob\(/);
  assert.match(js, /res\('timeout'\); \}, 3000\)/);
  assert.match(js, /alert\('이미지를 만들지 못했어요\. 이 화면을 캡처해 주세요\.'\)/);
});

test('이미지 글꼴 — 그릴 글자를 알려 주고 받는다(조각 글꼴), 못 받으면 font 오류로', () => {
  const js = read('js/birthday.js');
  assert.match(js, /document\.fonts\.load\(SERIF, serifText\)/);
  assert.match(js, /document\.fonts\.load\(SANS, sansText\)/);
  assert.match(js, /var serifText = r\.w \+ r\.x\.map/);
  assert.match(js, /var sansText = r\.date \+ '의 우리말' \+ r\.m/);
});

test('외부 스크립트 오류는 거른다 — 우리 주소의 파일만, iabjs:// 등은 빼고', () => {
  const js = read('js/birthday.js');
  const src = js.match(/function ours\(file, stack\) \{[\s\S]*?\n  \}/)[0];
  const ours = new Function('location', src + '; return ours;')({ origin: 'https://mongdol-desk.vercel.app' });
  assert.equal(ours('https://mongdol-desk.vercel.app/js/birthday.js', ''), true);
  assert.equal(ours('', 'Error | at sendDataToNative (iabjs://navigation_performance_logger_android:1:11853)'), false);
  assert.equal(ours('iabjs://navigation_performance_logger_android', ''), false);
  assert.equal(ours('', ''), false, 'Script error. — 다른 출처');
  assert.equal(ours('https://www.instagram.com/static/x.js', ''), false);
  assert.match(js, /send\('birthday_image', \{ via: 'hold' \}\)/);
});

test('저장 화면 분기 — 안드로이드 앱 안은 캡처 안내 + 크롬(카톡은 외부 브라우저)으로 같은 결과, 아이폰 앱 안은 길게 누르기, 일반 브라우저는 내려받기', () => {
  const js = read('js/birthday.js');
  assert.match(js, /var ANDROID_IN_APP = \/Android\/\.test\(ua\) && base\.browser_app !== 'browser';/);
  assert.match(js, /'이 화면을 캡처해서 저장해 주세요\./);
  assert.match(js, /'kakaotalk:\/\/web\/openExternal\?url=' \+ encodeURIComponent\(url\)/);
  assert.match(js, /package=com\.android\.chrome;S\.browser_fallback_url=/);
  assert.match(js, /'\/birthday\?m=' \+ last\.mo \+ '&d=' \+ last\.da \+ '&k=' \+ encodeURIComponent\(seed\) \+ '&save=1/);
  assert.match(js, /var carried = /);
  for (const v of ['external', 'download']) assert.match(js, new RegExp(`send\\('birthday_image', \\{ via: '${v}' \\}\\)`), v);
});
