// 알림 일정 계산 — iOS ArrivalNoticeTests 와 같은 사례 + 일정 전체 상황. TZ=Asia/Seoul 로 돈다(npm test).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { arrivalPlan, arrivalTargets, fires, eveningMinutes, dayNumber, schedule, BODY } from '../js/notice.js';
import { shiftKey } from '../js/day.js';

const at = (y, m, d, h, mi = 0) => new Date(y, m - 1, d, h, mi).getTime();
const fmt = (ms) => { const d = new Date(ms); return `${d.getMonth() + 1}/${d.getDate()} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; };

test('시험은 서울 시각으로 돈다', () => {
  assert.equal(new Date(2026, 9, 6).getTimezoneOffset(), -540);
});

// ── ArrivalNoticeTests 와 같은 사례 ──
const plan = (o = {}) => arrivalPlan({ key: '2026-09-24', hasPebble: true, closed: false, gifted: false, nowMs: at(2026, 9, 24, 12), ...o });

test('사진 없으면 / 일찍 닫았으면 / 받았으면 도착 소식 없음', () => {
  assert.equal(plan({ hasPebble: false }), null);
  assert.equal(plan({ closed: true }), null);
  assert.equal(plan({ gifted: true }), null);
});
test('발화는 다음 날 08:00, 08시 지나면 없음', () => {
  assert.equal(plan().at, at(2026, 9, 25, 8));
  assert.equal(plan({ nowMs: at(2026, 9, 25, 9) }), null);
});
test('새벽 2시 — dayKey 는 아직 어제, 그날 아침 8시에 온다', () => {
  assert.equal(plan({ key: '2026-09-23', nowMs: at(2026, 9, 24, 2) }).at, at(2026, 9, 24, 8));
});
test('도착 소식 문구엔 이름·색이 없다', () => {
  assert.equal(BODY.arrival, '어제의 조약돌이 도착했어요.');
});
test('targets — 4시 경계 · 8시까지 어제 유지 · 달 넘김', () => {
  assert.deepEqual(arrivalTargets(at(2026, 9, 25, 3, 59)), ['2026-09-24']);
  assert.deepEqual(arrivalTargets(at(2026, 9, 25, 4, 1)), ['2026-09-24', '2026-09-25']);
  assert.deepEqual(arrivalTargets(at(2026, 9, 25, 7, 59)), ['2026-09-24', '2026-09-25']);
  assert.deepEqual(arrivalTargets(at(2026, 9, 25, 8, 1)), ['2026-09-25']);
  assert.deepEqual(arrivalTargets(at(2026, 9, 25, 23)), ['2026-09-25']);
  assert.deepEqual(arrivalTargets(at(2026, 10, 1, 5)), ['2026-09-30', '2026-10-01']);
});
test('가끔은 달력 한 주(월~일)에 딱 이틀, 자주는 7일, 받지 않기는 0', () => {
  for (let w = 0; w < 20; w++) {
    const days = Array.from({ length: 7 }, (_, d) => shiftKey('2026-10-05', w * 7 + d));
    assert.equal(days.filter((k) => fires(k, 'sometimes')).length, 2, days[0]);
    assert.equal(days.filter((k) => fires(k, 'often')).length, 7);
    assert.equal(days.filter((k) => fires(k, 'off')).length, 0);
  }
});
test('가끔의 두 날은 2~4일 간격(주를 넘겨 감기면 7-간격)', () => {
  for (let w = 0; w < 52; w++) {
    const idx = Array.from({ length: 7 }, (_, d) => d).filter((d) => fires(shiftKey('2026-10-05', w * 7 + d), 'sometimes'));
    const gap = idx[1] - idx[0];
    assert.ok([2, 3, 4, 5].includes(gap) && (gap <= 4 || 7 - gap >= 2), `${w}주: ${idx}`);
  }
});
test('노을 시각은 계절을 따른다', () => {
  const winter = eveningMinutes('2026-12-20'), summer = eveningMinutes('2026-06-20');
  assert.ok(winter >= 16 * 60 + 50 && winter <= 17 * 60 + 10, String(winter));
  assert.ok(summer >= 19 * 60 + 25 && summer <= 19 * 60 + 40, String(summer));
  assert.ok(eveningMinutes('2026-10-31') < eveningMinutes('2026-10-01'));
});
test('dayNumber 는 PebbleNaming 과 같다', () => {
  assert.equal(dayNumber('1970-01-01'), 0);
  assert.equal(dayNumber('2026-09-30'), 20726);
  assert.equal(dayNumber('2024-03-01') - dayNumber('2024-02-28'), 2);
  assert.equal(dayNumber(''), null);
  assert.equal(dayNumber('2026-13-01'), null);
});
test('Swift 원본 함수로 뽑은 2026~2027 하루마다 값(가끔 여부·노을 분·dayNumber)과 전부 같다', () => {
  const ios = JSON.parse(readFileSync(new URL('./ios-reminder-parity.json', import.meta.url)));
  let n = 0;
  for (const [key, [f, eve, num]] of Object.entries(ios)) {
    assert.equal(fires(key, 'sometimes'), f, `${key} fires`);
    assert.equal(eveningMinutes(key), eve, `${key} evening`);
    assert.equal(dayNumber(key), num, `${key} dayNumber`);
    n++;
  }
  assert.equal(n, 732);
});

// ── 일정 전체 ──
function day({ pebbles = [], closed = [], giftedFloor = null, todayCount = 0 } = {}) {
  return {
    hasSealedMoments: (k) => pebbles.includes(k),
    closedAt: (k) => (closed.includes(k) ? 1 : null),
    isGifted: (k) => giftedFloor != null && k <= giftedFloor,
    todayCount,
  };
}
const list = (items) => items.map((i) => `${i.kind}:${i.key}@${fmt(i.at)}`);

test('자주 · 오늘 사진 없음 · 오후 1시 — 오늘 노을부터 7일치(아침·노을)', () => {
  const items = schedule(day(), { nowMs: at(2026, 10, 6, 13), frequency: 'often' });
  assert.equal(items.filter((i) => i.kind === 'morning').length, 6); // 오늘 09:00 은 지났다
  assert.equal(items.filter((i) => i.kind === 'evening').length, 7);
  assert.equal(list(items)[0], `evening:2026-10-06@10/6 ${fmt(at(2026, 10, 6, 0, eveningMinutes('2026-10-06'))).split(' ')[1]}`);
  assert.equal(items.at(-1).key, '2026-10-12');
  assert.ok(items.every((i, k) => k === 0 || items[k - 1].at <= i.at));
  assert.ok(items.length <= 30);
});
test('오늘 사진이 있으면 오늘 남은 알림이 빠지고 내일 아침 도착 소식 · 내일 아침 한 줄은 빠진다', () => {
  const items = schedule(day({ pebbles: ['2026-10-06'], todayCount: 2 }), { nowMs: at(2026, 10, 6, 13), frequency: 'often' });
  const l = list(items);
  assert.ok(!l.some((s) => s.includes(':2026-10-06@') && !s.startsWith('arrival')), l.join('\n'));
  assert.equal(l[0], 'arrival:2026-10-06@10/7 08:00');
  assert.ok(!l.includes('morning:2026-10-07@10/7 09:00'));
  assert.ok(l.some((s) => s.startsWith('evening:2026-10-07')));
});
test('일찍 닫은 날은 도착 소식 없음(그 대신 아침 한 줄이 남는다)', () => {
  const items = schedule(day({ pebbles: ['2026-10-06'], closed: ['2026-10-06'], todayCount: 1 }), { nowMs: at(2026, 10, 6, 21), frequency: 'often' });
  assert.ok(!items.some((i) => i.kind === 'arrival'));
  assert.ok(list(items).includes('morning:2026-10-07@10/7 09:00'));
});
test('받은 날(floor 이하)은 도착 소식 없음', () => {
  const nowMs = at(2026, 10, 7, 6); // 4~8시 — 어제 소식이 아직 남은 시간
  const before = schedule(day({ pebbles: ['2026-10-06'] }), { nowMs, frequency: 'off' });
  assert.deepEqual(list(before), ['arrival:2026-10-06@10/7 08:00']);
  const after = schedule(day({ pebbles: ['2026-10-06'], giftedFloor: '2026-10-06' }), { nowMs, frequency: 'off' });
  assert.deepEqual(after, []);
});
test('받지 않기여도 도착 소식은 따로 온다', () => {
  const items = schedule(day({ pebbles: ['2026-10-06'], todayCount: 1 }), { nowMs: at(2026, 10, 6, 13), frequency: 'off' });
  assert.deepEqual(list(items), ['arrival:2026-10-06@10/7 08:00']);
});
test('가끔 — 7일 안에 고른 요일에만, 날마다 아침·노을 둘', () => {
  const nowMs = at(2026, 10, 5, 5); // 월요일 새벽 5시
  const items = schedule(day(), { nowMs, frequency: 'sometimes' });
  const keys = [...new Set(items.map((i) => i.key))];
  assert.ok(keys.every((k) => fires(k, 'sometimes')));
  const expected = Array.from({ length: 7 }, (_, d) => shiftKey('2026-10-05', d)).filter((k) => fires(k, 'sometimes'));
  assert.deepEqual(keys, expected);
  for (const k of keys) assert.equal(items.filter((i) => i.key === k).length, 2);
});
test('4시 경계 — 새벽 2시엔 iOS 처럼 key 는 어제, 발화는 오늘 달력 날짜', () => {
  const items = schedule(day(), { nowMs: at(2026, 10, 7, 2), frequency: 'often' });
  assert.equal(list(items)[0], 'morning:2026-10-06@10/7 09:00');
  assert.equal(items.length, 14);
});
test('새벽 2시, 어젯밤 담았으면 — 어제 소식 08시 + 그 키의 아침 한 줄은 오늘이라 빠진다', () => {
  const items = schedule(day({ pebbles: ['2026-10-06'], todayCount: 1 }), { nowMs: at(2026, 10, 7, 2), frequency: 'often' });
  const l = list(items);
  assert.equal(l[0], 'arrival:2026-10-06@10/7 08:00');
  assert.ok(!l.some((s) => s.includes(':2026-10-06@') && !s.startsWith('arrival')));
});
test('일몰 알림 시각이 일정에 그대로 들어간다(겨울)', () => {
  const items = schedule(day(), { nowMs: at(2026, 12, 20, 10), frequency: 'often' });
  const eve = items.find((i) => i.kind === 'evening' && i.key === '2026-12-20');
  assert.equal(eve.at, at(2026, 12, 20, 0, eveningMinutes('2026-12-20')));
});
