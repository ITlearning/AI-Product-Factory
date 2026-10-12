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
  $('form').addEventListener('submit', function (e) {
    e.preventDefault();
    var m = Number(month.value), d = Number(day.value);
    table.then(function (t) {
      var w = t[String(m).padStart(2, '0') + String(d).padStart(2, '0')];
      if (!w) return;
      $('date').textContent = m + '월 ' + d + '일의 우리말';
      $('word').textContent = w.w;
      $('meaning').textContent = w.m;
      $('card').dataset.season = SEASON[m];
      $('form').hidden = true;
      $('result').hidden = false;
      $('copied').hidden = true;
      window.scrollTo(0, 0);
      send('birthday_shown');
    });
  });
  $('again').addEventListener('click', function () { $('result').hidden = true; $('form').hidden = false; });

  // 결과가 아니라 이 도구를 건넨다 — 주소에 생일을 싣지 않는다.
  $('share').addEventListener('click', function () {
    send('birthday_share');
    var url = location.origin + '/birthday?utm_source=share';
    var text = '생일을 고르면 그날의 우리말 하나를 알려 줘요';
    if (navigator.share) { navigator.share({ title: '내 생일의 우리말', text: text, url: url }).catch(function () {}); return; }
    navigator.clipboard && navigator.clipboard.writeText(url).then(function () { $('copied').hidden = false; });
  });
  $('app').addEventListener('click', function () { send('birthday_app_click'); });
})();
