// 생일 → 우리말 고르기. 같은 생일이어도 사람(브라우저)마다 다른 말, 한 브라우저에서는 언제나 같은 말.
// seed 는 브라우저마다 한 번 만든 무작위 열쇠(birthday.js 가 localStorage 에 둔다, 밖으로 보내지 않음).
// 그 달에 어울리는 말을 seed 로 섞어 날짜 순서대로 나눠 준다 — 한 브라우저 안에서 같은 달 다른 날짜끼리는 대표 말이 겹치지 않는다.
// 원본(data/birthday-words.json)의 순서가 바뀌면 모두의 말이 바뀐다. 말을 더하거나 뺄 때는 끝에 붙이거나 그 자리에서만 고칠 것.
var birthdayPick = (function () {
  // 날짜가 정해진 말은 그 날에만, 그 날에서도 넷 중 하나꼴로 나온다(어린이날이 5월 29일에 나오지 않게).
  var DAY = { '0101': '해맞이', '0505': '어린이날', '0508': '어버이날', '1231': '해넘이' };
  var dayWords = Object.keys(DAY).map(function (k) { return DAY[k]; });
  function hash(s) { var h = 2166136261; for (var i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); } return h >>> 0; }
  function rng(a) { return function () { a |= 0; a = (a + 0x6D2B79F5) | 0; var t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
  function perm(list, key) {
    var r = rng(hash(key)), a = list.slice();
    for (var i = a.length - 1; i > 0; i--) { var j = Math.floor(r() * (i + 1)), t = a[i]; a[i] = a[j]; a[j] = t; }
    return a;
  }
  function two(n) { return (n < 10 ? '0' : '') + n; }
  function plain(w) { return { w: w.w, m: w.m }; }
  return function pick(words, seed, m, d) {
    var month = words.filter(function (w) { return w.months.indexOf(m) >= 0 && dayWords.indexOf(w.w) < 0; });
    var any = words.filter(function (w) { return w.months.length === 0; });
    var pm = perm(month, seed + ':' + m), pa = perm(any, seed + ':any'), L = pm.length;
    var key = two(m) + two(d), special = DAY[key] && hash(seed + ':' + key) % 4 === 0;
    var main = special ? words.filter(function (w) { return w.w === DAY[key]; })[0] : pm[(d - 1) % L];
    // 곁말 하나는 그 달 말 중 대표로 안 나가는 뒤쪽(31번째부터)에서, 하나는 아무 때나 좋은 말에서.
    var x1 = L > 31 ? pm[31 + (d - 1) % (L - 31)] : pm[(d + 14) % L];
    var x2 = pa[((m - 1) * 31 + d - 1) % pa.length];
    return { w: main.w, m: main.m, x: [plain(x1), plain(x2)], pool: L + (DAY[key] ? 1 : 0) };
  };
})();
