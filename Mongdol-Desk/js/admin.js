// 관리(/admin) — 지금은 건의함 한 칸 — 토큰은 이 브라우저 localStorage 에만 둔다. 글은 전부 textContent 로 넣는다(사용자 글이라).
(function () {
  'use strict';
  var KEY = 'mongdol.desk.token';
  var PAGE = 50;
  var KIND = { bug: '불편한 점', wish: '바라는 기능', etc: '그 밖에' };
  var $ = function (id) { return document.getElementById(id); };

  function load() { try { return localStorage.getItem(KEY) || ''; } catch (e) { return ''; } }
  function save(v) { try { if (v) localStorage.setItem(KEY, v); else localStorage.removeItem(KEY); } catch (e) { /* 기억 못 해도 이번엔 쓴다 */ } }

  var token = load();
  var items = [];
  var total = 0;
  var busy = false;

  var when = new Intl.DateTimeFormat('ko-KR', { timeZone: 'Asia/Seoul', month: 'long', day: 'numeric', weekday: 'short', hour: 'numeric', minute: '2-digit' });

  function showLogin(message) {
    $('ad-main').hidden = true;
    $('ad-login').hidden = false;
    var err = $('ad-login-error');
    err.textContent = message || '';
    err.hidden = !message;
    $('ad-token').focus();
  }

  function api(method, query, body) {
    return fetch('/api/admin/feedback' + (query || ''), {
      method: method,
      headers: Object.assign({ authorization: 'Bearer ' + token }, body ? { 'content-type': 'application/json' } : {}),
      body: body ? JSON.stringify(body) : undefined,
      cache: 'no-store',
    }).then(function (res) {
      return res.json().catch(function () { return {}; }).then(function (json) {
        if (res.status === 401) { save(''); token = ''; showLogin('토큰이 맞지 않아요.'); throw new Error('401'); }
        if (res.status === 429) { showLogin('여러 번 틀렸어요. 15분 뒤에 다시 해 주세요.'); throw new Error('429'); }
        if (res.status === 503) { showLogin('Vercel 에 ADMIN_TOKEN 이 아직 없어요.'); throw new Error('503'); }
        if (!res.ok) throw new Error(json.message || String(res.status));
        return json;
      });
    });
  }

  function mainError(message) {
    var err = $('ad-error');
    err.textContent = message || '';
    err.hidden = !message;
  }

  function fetchPage(reset) {
    if (busy) return;
    busy = true;
    mainError('');
    var offset = reset ? 0 : items.length;
    api('GET', '?offset=' + offset + '&limit=' + PAGE).then(function (out) {
      $('ad-login').hidden = true;
      $('ad-main').hidden = false;
      items = reset ? out.items : items.concat(out.items);
      total = out.total;
      render();
    }).catch(function (e) {
      if (!/^(401|429|503)$/.test(e.message)) mainError('불러오지 못했어요. 새로 고침을 눌러 주세요.');
    }).then(function () { busy = false; });
  }

  function filter() {
    var picked = document.querySelector('input[name="filter"]:checked');
    return picked ? picked.value : 'all';
  }

  function el(tag, cls, text) {
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text;
    return n;
  }

  function card(it) {
    var li = el('li', 'item' + (it.read ? ' read' : ''));
    var top = el('div', 'item-top');
    top.appendChild(el('span', 'kind ' + it.kind, KIND[it.kind] || it.kind));
    top.appendChild(el('span', 'num', when.format(new Date(it.at))));
    if (!it.read) { var dot = el('span', 'dot'); dot.setAttribute('aria-label', '안 읽음'); top.appendChild(dot); }
    li.appendChild(top);
    li.appendChild(el('p', 'item-text', it.text));
    if (it.contact) li.appendChild(el('p', 'item-contact', '답장: ' + it.contact));
    var meta = [];
    if (it.v) meta.push('몽돌 ' + it.v + (it.b ? ' (' + it.b + ')' : ''));
    if (it.d) meta.push(it.d);
    if (meta.length) li.appendChild(el('p', 'item-meta num', meta.join(' · ')));

    var actions = el('div', 'item-actions');
    var readBtn = el('button', 'ghost-btn', it.read ? '안 읽음으로' : '읽음으로');
    readBtn.type = 'button';
    readBtn.addEventListener('click', function () {
      readBtn.disabled = true;
      api('PATCH', '', { id: it.id, read: !it.read }).then(function () { it.read = !it.read; render(); })
        .catch(function (e) { readBtn.disabled = false; if (!/^(401|429|503)$/.test(e.message)) mainError('바꾸지 못했어요.'); });
    });
    var delBtn = el('button', 'ghost-btn danger', '지우기');
    delBtn.type = 'button';
    delBtn.addEventListener('click', function () {
      if (!window.confirm('이 건의를 지울까요? 되돌릴 수 없어요.')) return;
      delBtn.disabled = true;
      api('DELETE', '', { id: it.id }).then(function () {
        items = items.filter(function (x) { return x.id !== it.id; });
        total = Math.max(0, total - 1);
        render();
      }).catch(function (e) { delBtn.disabled = false; if (!/^(401|429|503)$/.test(e.message)) mainError('지우지 못했어요.'); });
    });
    actions.appendChild(readBtn);
    actions.appendChild(delBtn);
    li.appendChild(actions);
    return li;
  }

  function render() {
    var f = filter();
    var shown = items.filter(function (it) { return f === 'all' || (f === 'unread' ? !it.read : it.kind === f); });
    var unread = items.filter(function (it) { return !it.read; }).length;
    $('ad-summary').textContent = '모두 ' + total + '개 · 불러온 ' + items.length + '개 중 안 읽은 것 ' + unread + '개';
    var list = $('ad-list');
    list.textContent = '';
    shown.forEach(function (it) { list.appendChild(card(it)); });
    $('ad-empty').hidden = shown.length > 0;
    $('ad-empty').textContent = items.length ? '이 종류는 없어요.' : '아직 받은 건의가 없어요.';
    $('ad-more').hidden = items.length >= total;
  }

  $('ad-login').addEventListener('submit', function (e) {
    e.preventDefault();
    var v = $('ad-token').value.trim();
    if (!v) return;
    token = v;
    save(v);
    $('ad-token').value = '';
    fetchPage(true);
  });
  $('ad-reload').addEventListener('click', function () { fetchPage(true); });
  $('ad-more').addEventListener('click', function () { fetchPage(false); });
  $('ad-lock').addEventListener('click', function () { save(''); token = ''; items = []; showLogin(''); });
  document.querySelectorAll('input[name="filter"]').forEach(function (r) { r.addEventListener('change', render); });

  if (token) fetchPage(true); else showLogin('');
})();
