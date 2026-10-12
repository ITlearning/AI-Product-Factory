// 릴스 프레임 찍기 — 크롬 하나를 띄워 card.html 의 frame(t) 를 넘기며 JPEG 를 찍는다.
//   node reel.mjs <card.html URL> <프레임 폴더> [fps]
import { spawn } from 'node:child_process';
import { mkdirSync, rmSync, writeFileSync } from 'node:fs';

const [, , url, outDir, fpsArg] = process.argv;
const fps = Number(fpsArg || 30);
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
rmSync(outDir, { recursive: true, force: true });
mkdirSync(outDir, { recursive: true });

const chrome = spawn(CHROME, ['--headless=new', '--disable-gpu', '--hide-scrollbars', '--allow-file-access-from-files',
  '--remote-debugging-port=0', '--user-data-dir=.work/chrome', '--window-size=1080,1920', 'about:blank'],
  { stdio: ['ignore', 'ignore', 'pipe'] });
const port = await new Promise((ok, fail) => {
  let log = '';
  chrome.stderr.on('data', d => { log += d; const m = log.match(/DevTools listening on ws:\/\/[^:]+:(\d+)\//); if (m) ok(m[1]); });
  chrome.on('exit', () => fail(new Error('크롬이 꺼졌어요\n' + log)));
});

try {
  const page = (await (await fetch(`http://127.0.0.1:${port}/json/list`)).json()).find(t => t.type === 'page');
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise(ok => ws.addEventListener('open', ok));
  let seq = 0; const pending = new Map(), waiters = new Map();
  ws.addEventListener('message', e => {
    const m = JSON.parse(e.data);
    if (m.id && pending.has(m.id)) { const p = pending.get(m.id); pending.delete(m.id); m.error ? p.fail(new Error(m.error.message)) : p.ok(m.result); }
    if (m.method && waiters.has(m.method)) { waiters.get(m.method)(); waiters.delete(m.method); }
  });
  const send = (method, params = {}) => new Promise((ok, fail) => { const id = ++seq; pending.set(id, { ok, fail }); ws.send(JSON.stringify({ id, method, params })); });
  const evaluate = async expression => {
    const r = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
    if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || expression);
    return r.result.value;
  };

  await send('Page.enable');
  await send('Emulation.setDeviceMetricsOverride', { width: 1080, height: 1920, deviceScaleFactor: 1, mobile: false });
  const loaded = new Promise(ok => waiters.set('Page.loadEventFired', ok));
  await send('Page.navigate', { url });
  await loaded;
  const length = await evaluate('window.ready.then(() => window.reelLength)');
  const count = Math.round(length * fps);
  for (let i = 0; i < count; i++) {
    await evaluate(`frame(${i / fps})`);
    const { data } = await send('Page.captureScreenshot', { format: 'jpeg', quality: 95 });
    writeFileSync(`${outDir}/f${String(i).padStart(5, '0')}.jpg`, Buffer.from(data, 'base64'));
  }
  ws.close();
  console.log(count);
} finally {
  chrome.kill();
}
