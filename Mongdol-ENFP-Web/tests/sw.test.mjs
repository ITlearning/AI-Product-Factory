// sw.js 를 그대로 vm 에 올려 push · notificationclick 처리만 본다.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import { payloadFor } from '../api/_lib/push.js';

function loadSW({ windows = [] } = {}) {
  const handlers = {};
  const shown = [];
  const opened = [];
  const self = {
    location: new URL('https://mongdol-enfp.vercel.app/sw.js'),
    addEventListener: (t, fn) => { handlers[t] = fn; },
    skipWaiting() {},
    registration: { showNotification: async (title, opts) => { shown.push({ title, ...opts }); } },
    clients: {
      claim: async () => {},
      matchAll: async () => windows,
      openWindow: async (url) => { opened.push(url); },
    },
  };
  vm.runInNewContext(readFileSync(new URL('../sw.js', import.meta.url), 'utf8'), { self, caches: {}, fetch: () => {}, URL, console });
  return { handlers, shown, opened };
}

async function push(sw, data) {
  const waits = [];
  sw.handlers.push({ data, waitUntil: (p) => waits.push(p) });
  assert.equal(waits.length, 1, 'waitUntil 로 감싼다');
  await Promise.all(waits);
}

const text = (s) => ({ text: () => s });

test('서버 페이로드(Declarative)를 그대로 띄운다', async () => {
  const sw = loadSW();
  await push(sw, text(JSON.stringify(payloadFor('evening', '2026-10-06'))));
  assert.equal(sw.shown.length, 1);
  assert.equal(sw.shown[0].title, '몽돌');
  assert.equal(sw.shown[0].body, '노을 지는 시간이에요. 순간을 남겨 보는 건 어때요?');
  assert.equal(sw.shown[0].tag, 'reminder-2026-10-06-evening');
  assert.equal(sw.shown[0].data.url, 'https://mongdol-enfp.vercel.app/');
  assert.equal(sw.shown[0].badge, undefined);
});

test('깨진 JSON · 빈 데이터 · data 없음 · text() 가 던져도 기본 문구로 반드시 띄운다', async () => {
  const sw = loadSW();
  await push(sw, text('{broken'));
  await push(sw, text(''));
  await push(sw, null);
  await push(sw, { text: () => { throw new Error('x'); } });
  await push(sw, text(JSON.stringify({ notification: { title: 5, body: null } })));
  assert.equal(sw.shown.length, 5);
  for (const n of sw.shown) { assert.equal(n.title, '몽돌'); assert.equal(n.body, '어제의 조약돌이 도착했어요.'); }
});

test('알림을 누르면 열린 창을 앞으로, 없으면 새 창', async () => {
  let focused = 0, closed = 0;
  const win = { url: 'https://mongdol-enfp.vercel.app/?x', focus: async () => { focused++; } };
  const notification = { close: () => { closed++; } };
  for (const [windows, expectOpen] of [[[win], 0], [[], 1]]) {
    const sw = loadSW({ windows });
    const waits = [];
    sw.handlers.notificationclick({ notification, waitUntil: (p) => waits.push(p) });
    await Promise.all(waits);
    assert.equal(sw.opened.length, expectOpen);
    if (expectOpen) assert.deepEqual(sw.opened, ['./']);
  }
  assert.equal(focused, 1);
  assert.equal(closed, 2);
});

test('서비스 워커는 /api/ 요청을 가로채지 않는다', () => {
  const sw = loadSW();
  let responded = false;
  sw.handlers.fetch({ request: { method: 'GET', url: 'https://mongdol-enfp.vercel.app/api/push-send', mode: 'cors' }, respondWith: () => { responded = true; } });
  assert.equal(responded, false);
});
