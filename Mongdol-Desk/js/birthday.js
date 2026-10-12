// /birthday — 생일(월·일) → data/birthday.json 의 우리말 하나. 같은 생일이면 누구나 같은 말.
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
  };
  ['utm_source', 'utm_medium', 'utm_campaign', 'utm_content'].forEach(function (k) { if (q.get(k)) base[k] = q.get(k); });
  function send(event) {
    var body = JSON.stringify({ api_key: KEY, event: event, distinct_id: id, timestamp: new Date().toISOString(), properties: base });
    if (!(navigator.sendBeacon && navigator.sendBeacon(URL_, new Blob([body], { type: 'text/plain' })))) {
      fetch(URL_, { method: 'POST', body: body, keepalive: true, headers: { 'Content-Type': 'text/plain' } }).catch(function () {});
    }
  }
  send('$pageview');

  var $ = function (s) { return document.getElementById(s); };
  var INSTA = 'mongdol.app'; // 몽돌 인스타 아이디 — 비우면 팔로우 링크를 숨긴다
  var IOS = /iPhone|iPad|iPod/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
  if (INSTA) {
    var insta = $('insta');
    insta.href = 'https://www.instagram.com/' + INSTA + '/';
    insta.hidden = false;
    insta.addEventListener('click', function () { send('birthday_insta_click'); });
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

  var table = fetch('./data/birthday.json').then(function (r) { return r.json(); });
  // 두구두구 — 카드 안에서 다른 말들이 빠르게 지나가다 점점 느려지고, 번짐이 숨 쉬다가 제 말에 멈춘다.
  // 도는 동안 카드를 누르면 바로 멈춘다. 움직임 줄이기면 돌리지 않는다.
  var stop = null;
  function letters(el, text) {
    el.textContent = '';
    Array.from(text).forEach(function (ch, i) { var s = document.createElement('span'); s.textContent = ch; s.style.setProperty('--i', i); el.append(s); });
    el.setAttribute('aria-label', text);
  }
  function roll(t, done) {
    var all = Object.keys(t), word = $('word'), result = $('result'), at = 0, ticks = 0, timer = null, ended = false;
    result.classList.add('bd-rolling');
    function tick() {
      word.textContent = t[all[Math.floor(Math.random() * all.length)]].w;
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
    table.then(function (t) {
      var w = t[String(m).padStart(2, '0') + String(d).padStart(2, '0')];
      if (!w) return;
      var word = $('word'), date = $('date');
      $('bridge').textContent = m + '월 ' + d + '일의 우리말은 「' + w.w + '」였어요.';
      $('meaning').textContent = w.m;
      $('card').dataset.season = SEASON[m];
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
})();
