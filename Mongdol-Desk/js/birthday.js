// /birthday — 생일(월·일) → 그 달에 어울리는 우리말 하나(고르기는 birthday-pick.js). 같은 생일이어도 사람마다 다르고, 한 브라우저에선 늘 같다.
// 생일은 서버로 보내지 않는다. 세는 건 조회·결과 봄·공유·앱 보러 가기 누름뿐(날짜 없이) — get.html 과 같은 PostHog(EU), 저장소·프로필 없이.
(function () {
  var KEY = 'phc_nQAKwQjfrQnNCXC4FomYsLBH79wA4jVnokYKw7uMLicK';
  var URL_ = 'https://eu.i.posthog.com/i/v0/e/';
  var id = (window.crypto && crypto.randomUUID) ? crypto.randomUUID() : String(Date.now()) + Math.random().toString(16).slice(2);
  var q = new URLSearchParams(location.search);
  var ua = navigator.userAgent;
  var base = {
    $lib: 'web', $current_url: location.origin + location.pathname, $host: location.host, $pathname: location.pathname,
    $referrer: document.referrer || '$direct', $screen_width: screen.width, $screen_height: screen.height,
    $browser_language: navigator.language,
    $os: /iPhone|iPad|iPod/.test(ua) ? 'iOS' : /Android/.test(ua) ? 'Android' : /Mac OS X/.test(ua) ? 'Mac OS X' : /Windows/.test(ua) ? 'Windows' : 'Other',
    $device_type: /iPad|Tablet/.test(ua) ? 'Tablet' : /Mobi|iPhone|Android/.test(ua) ? 'Mobile' : 'Desktop',
    $process_person_profile: false, $geoip_disable: true,
    // 어느 앱 안에서 열었나 — 앱 안 브라우저마다 공유·내려받기 지원이 달라 고장을 가르는 데 쓴다.
    browser_app: /KAKAOTALK/.test(ua) ? 'kakao' : /Instagram/.test(ua) ? 'instagram' : /Barcelona/.test(ua) ? 'threads' : /FBAN|FBAV/.test(ua) ? 'facebook' : /Line\//.test(ua) ? 'line' : 'browser',
  };
  ['utm_source', 'utm_medium', 'utm_campaign', 'utm_content'].forEach(function (k) { if (q.get(k)) base[k] = q.get(k); });
  // Tabber 기기 표시 — ?internal=1 로 한 번 열면 이 브라우저의 기록에 internal 이 붙어 대시보드에서 빠진다(?internal=0 으로 해제).
  try {
    if (q.get('internal') === '1') localStorage.setItem('mongdol-internal', '1');
    if (q.get('internal') === '0') localStorage.removeItem('mongdol-internal');
    if (localStorage.getItem('mongdol-internal')) base.internal = true;
  } catch (e) {}
  function send(event, extra) {
    var props = Object.assign({}, base, extra || {});
    var body = JSON.stringify({ api_key: KEY, event: event, distinct_id: id, timestamp: new Date().toISOString(), properties: props });
    if (!(navigator.sendBeacon && navigator.sendBeacon(URL_, new Blob([body], { type: 'text/plain' })))) {
      fetch(URL_, { method: 'POST', body: body, keepalive: true, headers: { 'Content-Type': 'text/plain' } }).catch(function () {});
    }
  }
  send('$pageview');
  // 고장은 방문자가 먼저 본다 — 어디서·무슨 오류가·어떤 앱 안에서 났는지 자세히 남긴다. 생일·단어·열쇠는 넣지 않는다.
  var ready = null;
  function report(where, err, more) {
    var e = err || {};
    send('birthday_error', Object.assign({
      where: where,
      error_name: String(e.name || typeof e).slice(0, 60),
      error_message: String(e.message || e).slice(0, 300),
      error_stack: String(e.stack || '').split('\n').slice(0, 4).join(' | ').slice(0, 500),
      can_share: !!navigator.share,
      image_ready: !!ready,
    }, more || {}));
  }
  // 앱 안 브라우저(인스타 iabjs:// 등)가 끼워 넣은 스크립트의 오류는 우리 고장이 아니다 — 우리 주소의 파일에서 난 것만 남긴다.
  // 다른 출처 스크립트는 파일 이름 없이 「Script error.」로만 오므로 그것도 거른다.
  function ours(file, stack) {
    var f = String(file || ''), s = String(stack || '');
    if (/iabjs:|chrome-extension:|safari-extension:|moz-extension:/.test(f + s)) return false;
    return f.indexOf(location.origin + '/') === 0;
  }
  window.addEventListener('error', function (e) {
    if (!ours(e.filename, e.error && e.error.stack)) return;
    report('page', e.error || { name: 'Error', message: e.message }, { source: String(e.filename || '').split('/').pop() + ':' + e.lineno + ':' + e.colno });
  });
  window.addEventListener('unhandledrejection', function (e) {
    var st = String((e.reason && e.reason.stack) || '');
    if (/iabjs:|chrome-extension:|safari-extension:|moz-extension:/.test(st)) return;
    report('promise', e.reason);
  });

  var $ = function (s) { return document.getElementById(s); };
  var INSTA = 'mongdol.app'; // 몽돌 인스타 아이디 — 비우면 팔로우 링크를 숨긴다
  var IOS = /iPhone|iPad|iPod/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
  if (INSTA) {
    var insta = $('insta');
    insta.href = 'https://www.instagram.com/' + INSTA + '/';
    insta.hidden = false;
    // 인스타·스레드·카톡·페북 내장 브라우저에서는 https 링크가 앱으로 안 넘어가고 내장 브라우저 안에서 웹 인스타(로그인 화면)가 열린다.
    // 그래서 인스타 앱을 직접 연다 — iPhone 은 instagram:// , 안드로이드는 intent:// . 1.2초 안에 앱으로 안 넘어가면 웹 주소로.
    // 사파리·크롬은 https 그대로 둔다(운영체제가 앱으로 넘겨 주고, 앱이 없을 때 instagram:// 는 오류 창을 띄운다).
    var inApp = /Instagram|Barcelona|KAKAOTALK|FBAN|FBAV|Line\//.test(ua);
    var web = insta.href;
    insta.addEventListener('click', function (e) {
      send('birthday_insta_click');
      if (!inApp) return;
      var app = IOS ? 'instagram://user?username=' + INSTA
        : /Android/.test(ua) ? 'intent://instagram.com/_u/' + INSTA + '/#Intent;package=com.instagram.android;scheme=https;S.browser_fallback_url=' + encodeURIComponent(web) + ';end'
        : null;
      if (!app) return;
      e.preventDefault();
      var left = false, mark = function () { left = true; };
      document.addEventListener('visibilitychange', mark, { once: true });
      window.addEventListener('pagehide', mark, { once: true });
      location.href = app;
      setTimeout(function () { if (!left && !document.hidden) location.href = web; }, 1200);
    });
  }
  // iPhone 이 아니면 받을 수 없는 앱 대신 인스타를 앞에 둔다.
  if (!IOS) {
    $('app').hidden = !!INSTA;
    $('iosNote').hidden = false;
    $('iosNote').textContent = /Android/.test(ua)
      ? '안드로이드 버전은 지금 준비하고 있어요. 인스타를 팔로우하고 소식을 기다려 주세요.'
      : '몽돌은 지금 iPhone 앱만 있어요.\n안드로이드 버전은 준비하고 있어요.';
    if (INSTA) { $('insta').className = 'primary-btn bd-insta'; $('insta').textContent = '인스타 팔로우하고 소식 받기'; }
  }

  // 화면 바꾸기 — 나가는 쪽을 흐리게 뺀 뒤 들어오는 쪽을 차례로 띄운다. 움직임 줄이기 설정이면 바로 바꾼다.
  var still = window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;
  function swap(from, to, after) {
    if (still) { from.hidden = true; to.hidden = false; after && after(); return; }
    from.classList.add('bd-out');
    setTimeout(function () {
      from.hidden = true; from.classList.remove('bd-out');
      to.classList.remove('bd-play'); to.hidden = false;
      void to.offsetWidth; // 같은 애니메이션을 다시 돌리려면 한 번 그려야 한다
      to.classList.add('bd-play');
      after && after();
    }, 260);
  }
  var month = $('month'), day = $('day');
  var SEASON = { 3: 'spring', 4: 'spring', 5: 'spring', 6: 'summer', 7: 'summer', 8: 'summer', 9: 'autumn', 10: 'autumn', 11: 'autumn', 12: 'winter', 1: 'winter', 2: 'winter' };
  for (var m = 1; m <= 12; m++) month.add(new Option(m + '월', m));
  function fillDays() {
    var keep = Number(day.value) || 1, last = new Date(2024, Number(month.value), 0).getDate(); // 2024 는 윤년 — 2월 29일도 고를 수 있게
    day.textContent = '';
    for (var d = 1; d <= last; d++) day.add(new Option(d + '일', d));
    day.value = String(Math.min(keep, last));
  }
  var now = new Date();
  month.value = String(now.getMonth() + 1);
  fillDays();
  day.value = String(now.getDate());
  month.addEventListener('change', fillDays);

  var words = fetch('./data/birthday-words.json').then(function (r) { return r.json(); });
  words.catch(function (e) { report('data', e); });
  // 브라우저마다 한 번 만드는 열쇠 — 같은 생일이어도 사람마다 다른 말, 다시 해도 같은 말. 저장소를 못 쓰면 이 화면 동안만.
  var seed = (function () {
    var fresh = (window.crypto && crypto.randomUUID) ? crypto.randomUUID() : String(Date.now()) + Math.random().toString(16).slice(2);
    try { var s = localStorage.getItem('mongdol-birthday-seed'); if (!s) { s = fresh; localStorage.setItem('mongdol-birthday-seed', s); } return s; } catch (e) { return fresh; }
  })();
  // 두구두구 — 카드 안에서 다른 말들이 빠르게 지나가다 점점 느려지고, 번짐이 숨 쉬다가 제 말에 멈춘다.
  // 도는 동안 카드를 누르면 바로 멈춘다. 움직임 줄이기면 돌리지 않는다.
  var stop = null;
  function letters(el, text) {
    el.textContent = '';
    Array.from(text).forEach(function (ch, i) { var s = document.createElement('span'); s.textContent = ch; s.style.setProperty('--i', i); el.append(s); });
    el.setAttribute('aria-label', text);
  }
  function roll(t, done) {
    var word = $('word'), result = $('result'), at = 0, ticks = 0, timer = null, ended = false;
    result.classList.add('bd-rolling');
    function tick() {
      word.textContent = t[Math.floor(Math.random() * t.length)].w;
      if (navigator.vibrate) navigator.vibrate(6);
      var gap = 55 + ticks * ticks * 2.2; // 처음엔 빠르게, 갈수록 느리게
      ticks++; at += gap;
      timer = setTimeout(at < 1700 ? tick : end, gap);
    }
    function end() {
      if (ended) return;
      ended = true; clearTimeout(timer); stop = null;
      result.classList.remove('bd-rolling', 'bd-play');
      void result.offsetWidth;
      result.classList.add('bd-play', 'bd-landed');
      if (navigator.vibrate) navigator.vibrate([12, 40, 24]);
      done();
    }
    stop = end;
    tick();
  }
  $('card').addEventListener('click', function () { stop && stop(); });

  $('form').addEventListener('submit', function (e) {
    e.preventDefault();
    var m = Number(month.value), d = Number(day.value);
    words.then(function (t) {
      var w = birthdayPick(t, seed, m, d);
      var word = $('word'), date = $('date');
      // 받침이 있으면 「이었어요」(갈대꽃이었어요), 없으면 「였어요」(진달래였어요).
      var end = w.w.charCodeAt(w.w.length - 1), batchim = end >= 0xAC00 && end <= 0xD7A3 && (end - 0xAC00) % 28 !== 0; // last 는 이미지 저장이 쓰는 이름 — 겹치면 저장이 멈춘다
      $('bridge').textContent = m + '월 ' + d + '일의 우리말은 「' + w.w + '」' + (batchim ? '이었어요.' : '였어요.');
      $('meaning').textContent = w.m;
      $('how').textContent = '이번 말은 ' + m + '월에 어울리는 말 ' + w.pool + '개 가운데서 골랐어요. 그중 하나를 사람마다 정해 드려서, 같은 생일이어도 친구와 다를 수 있고 다시 해 봐도 내 말은 그대로예요.';
      var more = $('more');
      more.textContent = '';
      w.x.forEach(function (x) {
        var li = document.createElement('li'), b = document.createElement('b'), s = document.createElement('span');
        b.textContent = x.w; s.textContent = x.m; li.append(b, s); more.append(li);
      });
      $('card').dataset.season = SEASON[m];
      last = { date: m + '월 ' + d + '일', w: w.w, m: w.m, x: w.x, season: SEASON[m] };
      prepareImage(last);
      $('copied').hidden = true;
      $('result').classList.remove('bd-landed');
      function land() { date.textContent = m + '월 ' + d + '일의 우리말'; letters(word, w.w); }
      if (still) land(); else { date.textContent = m + '월 ' + d + '일의 우리말은…'; word.textContent = ''; }
      swap($('form'), $('result'), function () {
        window.scrollTo({ top: 0, behavior: still ? 'auto' : 'smooth' });
        if (!still) setTimeout(function () { roll(t, land); }, 250);
      });
      send('birthday_shown');
    });
  });
  $('again').addEventListener('click', function () { stop && stop(); swap($('result'), $('form')); });

  // 결과가 아니라 이 도구를 건넨다 — 주소에 생일을 싣지 않는다.
  $('share').addEventListener('click', function () {
    send('birthday_share');
    var url = location.origin + '/birthday?utm_source=share';
    // 카톡 등은 text·url 을 줄바꿈 없이 붙여 버린다 — 글 한 줄 + 줄바꿈 + 주소를 text 하나로 넘긴다.
    var text = '생일을 고르면 그날의 우리말 하나를 알려 줘요\n' + url;
    if (navigator.share) { navigator.share({ title: '내 생일의 우리말', text: text }).catch(function () {}); return; }
    navigator.clipboard && navigator.clipboard.writeText(url).then(function () { $('copied').hidden = false; });
  });
  $('app').addEventListener('click', function () { send('birthday_app_click'); });

  // 이미지로 저장 — 결과 카드를 1080×1350 그림으로. 아래에 이 페이지 주소를 넣어 보는 사람이 직접 해 볼 수 있게.
  var GLOW = { spring: '244,165,190', summer: '120,200,160', autumn: '240,170,90', winter: '150,180,240' };
  var last = null;
  function wrap(ctx, text, maxW) {
    var lines = [], line = '';
    text.split(' ').forEach(function (word) {
      var t = line ? line + ' ' + word : word;
      if (ctx.measureText(t).width > maxW && line) { lines.push(line); line = word; } else line = t;
    });
    if (line) lines.push(line);
    return lines;
  }
  function drawCard(r) {
    var W = 1080, H = 1350, c = document.createElement('canvas'), x = c.getContext('2d');
    c.width = W; c.height = H;
    x.fillStyle = '#06070A'; x.fillRect(0, 0, W, H);
    var g = x.createRadialGradient(W / 2, 520, 0, W / 2, 520, 620);
    g.addColorStop(0, 'rgba(' + GLOW[r.season] + ',0.55)'); g.addColorStop(1, 'rgba(' + GLOW[r.season] + ',0)');
    x.fillStyle = g; x.fillRect(0, 0, W, H);
    x.textAlign = 'center'; x.textBaseline = 'alphabetic';
    var serif = '"Nanum Myeongjo", "AppleMyungjo", serif', sans = '"Gowun Dodum", -apple-system, sans-serif';
    x.fillStyle = 'rgba(255,255,255,0.64)'; x.font = '40px ' + sans; x.fillText(r.date + '의 우리말', W / 2, 330);
    var size = 190; x.font = '800 ' + size + 'px ' + serif;
    while (x.measureText(r.w).width > W - 160 && size > 90) { size -= 10; x.font = '800 ' + size + 'px ' + serif; }
    x.fillStyle = 'rgba(255,255,255,0.95)'; x.fillText(r.w, W / 2, 560);
    x.font = '44px ' + sans; x.fillStyle = 'rgba(255,255,255,0.72)';
    wrap(x, r.m, W - 220).forEach(function (l, i) { x.fillText(l, W / 2, 670 + i * 64); });
    x.fillStyle = 'rgba(255,255,255,0.42)'; x.font = '34px ' + sans; x.fillText('이날의 다른 말', W / 2, 930);
    x.fillStyle = 'rgba(255,255,255,0.8)'; x.font = '800 54px ' + serif; x.fillText(r.x.map(function (e) { return e.w; }).join('  ·  '), W / 2, 1010);
    x.fillStyle = 'rgba(255,255,255,0.88)'; x.font = '800 44px ' + serif; x.fillText('몽돌', W / 2, 1200);
    x.fillStyle = 'rgba(255,255,255,0.5)'; x.font = '32px ' + sans; x.fillText('mongdol-desk.vercel.app/birthday', W / 2, 1256);
    return c;
  }
  // 이미지는 결과가 뜨는 순간 미리 만든다 — 누른 뒤에 글꼴·그림을 기다리면 iPhone 은 「누른 직후」가 지나 공유 시트를 조용히 막는다.
  // 공유 시트가 파일을 받으면 시트로. 앱 안 브라우저(카톡 등)는 시트도 내려받기도 못 해서(「지원하지 않는 형식」) 그림을 띄우고 길게 눌러 저장하게 한다.
  // toBlob 은 일부 앱 안 브라우저에서 null 을 준다 — 이미지는 toDataURL 하나로 만들고, 공유용 파일도 거기서 만든다.
  // 한글 웹글꼴은 글자 조각(unicode-range)으로 나뉘어 있어, 그릴 글자를 알려 줘야 그 조각까지 받는다.
  // 글자 없이 load 하면 일부 조각만 받아 그림에 기본 글꼴이 섞인다(갤럭시 「뜰」, 아이폰은 통째로 고딕).
  var SERIF = '800 190px "Nanum Myeongjo"', SANS = '40px "Gowun Dodum"';
  function fontsReady(r) {
    var serifText = r.w + r.x.map(function (e) { return e.w; }).join('') + '몽돌·';
    var sansText = r.date + '의 우리말' + r.m + '이날의 다른 말mongdol-desk.vercel.app/birthday';
    if (!document.fonts || !document.fonts.load) return Promise.resolve();
    var p = Promise.all([document.fonts.load(SERIF, serifText), document.fonts.load(SANS, sansText)]).catch(function (e) { report('font', e); });
    var cap = new Promise(function (res) { setTimeout(function () { res('timeout'); }, 3000); });
    return Promise.race([p, cap]).then(function (v) {
      var missing = [];
      try {
        if (!document.fonts.check(SERIF, serifText)) missing.push('serif');
        if (!document.fonts.check(SANS, sansText)) missing.push('sans');
      } catch (e) {}
      if (v === 'timeout' || missing.length) report('font', { name: v === 'timeout' ? 'FontTimeout' : 'FontMissing', message: 'missing ' + (missing.join(',') || 'unknown') });
    });
  }
  function render(r) {
    try {
      var url = drawCard(r).toDataURL('image/png');
      if (!url || url.length < 1000) { report('draw', { name: 'EmptyImage', message: 'dataURL length ' + (url ? url.length : 0) }); return null; }
      return url;
    } catch (e) { report('draw', e); return null; }
  }
  function toFile(url, name) {
    var bin = atob(url.split(',')[1]), bytes = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    try { return new File([bytes], name, { type: 'image/png' }); } catch (e) { var b = new Blob([bytes], { type: 'image/png' }); b.name = name; return b; }
  }
  function prepareImage(r) {
    ready = null;
    fontsReady(r).then(function () {
      if (r !== last) return;
      var url = render(r);
      if (url) ready = { r: r, url: url, file: toFile(url, '내-생일의-우리말-' + r.w + '.png') };
    });
  }
  function showSheet(url) {
    $('sheetImg').src = url;
    $('sheet').hidden = false;
  }
  $('sheetClose').addEventListener('click', function () { $('sheet').hidden = true; });
  // 길게 누르면 contextmenu 가 온다 — 저장 메뉴가 실제로 떴는지는 모르지만, 누가 어느 앱에서 길게 눌러 봤는지는 남긴다.
  $('sheetImg').addEventListener('contextmenu', function () { send('birthday_image', { via: 'hold' }); });
  $('sheet').addEventListener('click', function (e) { if (e.target === $('sheet')) $('sheet').hidden = true; });
  var mobile = /iPhone|iPad|iPod|Android/.test(ua) || IOS;
  $('image').addEventListener('click', function () {
    if (!last) { report('image', { name: 'NoResult', message: 'image clicked without a result' }); return; }
    if (!ready || ready.r !== last) {
      // 아직 준비 전이면 글꼴을 다 받은 뒤 그려서 띄운다(그림 띄우기는 「누른 직후」가 필요 없다).
      var r = last;
      send('birthday_image', { via: 'sheet' });
      fontsReady(r).then(function () {
        var now = render(r);
        if (!now) { alert('이미지를 만들지 못했어요. 이 화면을 캡처해 주세요.'); return; }
        showSheet(now);
      });
      return;
    }
    var file = ready.file, url = ready.url;
    var canFiles = false;
    try { canFiles = !!(navigator.canShare && navigator.share && navigator.canShare({ files: [file] })); } catch (e) { report('canshare', e); }
    if (canFiles) {
      send('birthday_image', { via: 'share' });
      navigator.share({ files: [file] }).catch(function (err) {
        if (err && err.name === 'AbortError') return; // 사용자가 닫은 것
        report('share', err);
        showSheet(url);
      });
      return;
    }
    if (mobile) { send('birthday_image', { via: 'sheet' }); showSheet(url); return; }
    send('birthday_image', { via: 'download' });
    var a = document.createElement('a');
    a.href = url; a.download = '내-생일의-우리말-' + last.w + '.png';
    document.body.append(a); a.click(); a.remove();
  });;
})();
