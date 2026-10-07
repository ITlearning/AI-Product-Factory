// 건의하기(/feedback) — 앱이 ?v=<버전>&b=<빌드>&d=<기종> 을 붙여 앱 안 Safari 로 연다.
// 모듈이 아니라 그냥 스크립트다: file:// 로 열어 확인할 때도 뜨게.
(function () {
  'use strict';
  var MAX = 2000;
  var q = new URLSearchParams(location.search);
  // 서버 zod 와 같은 모양만 — 어긋나면 빈 값으로 보낸다(400 으로 글을 잃지 않게).
  function tag(name, re, max) {
    var s = (q.get(name) || '').trim();
    return s.length <= max && re.test(s) ? s : '';
  }
  var info = {
    v: tag('v', /^[0-9A-Za-z._-]*$/, 20),
    b: tag('b', /^[0-9A-Za-z._-]*$/, 20),
    d: tag('d', /^[0-9A-Za-z,._ -]*$/, 40),
  };

  var $ = function (id) { return document.getElementById(id); };
  var form = $('fb-form'), text = $('fb-text'), contact = $('fb-contact'), website = $('fb-website');
  var count = $('fb-count'), send = $('fb-send'), error = $('fb-error'), meta = $('fb-meta');

  var parts = [];
  if (info.v) parts.push('몽돌 ' + info.v + (info.b ? ' (' + info.b + ')' : ''));
  if (info.d) parts.push(info.d);
  if (parts.length) {
    meta.textContent = parts.join(' · ') + ' 정보가 함께 가요.';
    meta.hidden = false;
  }

  function newCid() {
    var a = new Uint8Array(16);
    crypto.getRandomValues(a);
    return Array.prototype.map.call(a, function (x) { return (x + 256).toString(16).slice(1); }).join('');
  }
  // 글이 바뀌지 않은 채 다시 보내면 같은 표 — 응답만 못 받은 경우 서버가 두 번 저장하지 않는다.
  var cid = newCid();
  var sending = false;

  function refresh() {
    var n = text.value.length;
    count.textContent = n.toLocaleString('ko-KR') + ' / ' + MAX.toLocaleString('ko-KR');
    count.classList.toggle('near', n >= MAX - 200);
    send.disabled = sending || !text.value.trim();
  }
  function edited() { cid = newCid(); error.hidden = true; refresh(); }
  text.addEventListener('input', edited);
  contact.addEventListener('input', edited);
  form.addEventListener('change', edited);
  refresh();

  function fail(message) {
    error.textContent = message;
    error.hidden = false;
  }

  form.addEventListener('submit', function (e) {
    e.preventDefault();
    if (sending || !text.value.trim()) return;
    sending = true;
    error.hidden = true;
    send.disabled = true;
    send.setAttribute('aria-busy', 'true');
    send.textContent = '보내는 중…';
    var picked = form.querySelector('input[name="kind"]:checked');
    var body = {
      kind: picked ? picked.value : 'etc',
      text: text.value,
      contact: contact.value,
      v: info.v, b: info.b, d: info.d,
      cid: cid,
      website: website.value,
    };
    var ctrl = typeof AbortController === 'function' ? new AbortController() : null;
    var timer = ctrl && setTimeout(function () { ctrl.abort(); }, 15000);
    fetch('/api/feedback', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
      signal: ctrl ? ctrl.signal : undefined,
    }).then(function (res) {
      if (res.ok) return done();
      if (res.status === 429) return fail('잠시 뒤에 다시 보내 주세요. 한 시간에 다섯 번까지 받아요.');
      if (res.status === 400 || res.status === 413) return fail('보낼 수 없는 글자가 섞였어요. 내용을 한 번 살펴봐 주세요.');
      fail('보내지 못했어요. 조금 뒤에 한 번 더 눌러 주세요.');
    }).catch(function () {
      fail('보내지 못했어요. 연결을 확인하고 한 번 더 눌러 주세요.');
    }).then(function () {
      if (timer) clearTimeout(timer);
      sending = false;
      send.removeAttribute('aria-busy');
      send.textContent = '보내기';
      refresh();
    });
  });

  function done() {
    form.hidden = true;
    var view = $('fb-done');
    view.hidden = false;
    window.scrollTo(0, 0);
    var title = view.querySelector('.done-title');
    if (title) title.focus({ preventScroll: true });
  }
})();
