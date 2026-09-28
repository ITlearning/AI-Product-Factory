// 「견본 하루 채우기」 — 사진 대신 캔버스로 풍경을 그려 넣고, 색은 실제 추출기로 뽑는다.
// 어제 하루는 일부러 안 받은 채로 둬서, 채우고 나면 곧바로 증정 세리머니를 볼 수 있다.
import { dayKey, dayStart, shiftKey } from './day.js';
import { hexToRgb } from './shape.js';
import { prepareCanvas } from './images.js';
import { rng } from './hash.js';
import { now } from './clock.js';

const DAYS = [
  { ago: 0, hexes: ['#FFE3A3', '#BDE3C4', '#F7B7C8'] },
  { ago: 1, hexes: ['#F6C28B', '#F29B7F', '#E0707A', '#9E5A8A'], hours: [15.6, 17.2, 18.3, 19.1] },
  { ago: 2, hexes: ['#A9D4F5', '#8CC3EE', '#6FA8DC'] },
  { ago: 3, hexes: ['#C4E39A', '#8CC57A', '#6FAF73'] },
  { ago: 5, hexes: ['#FFE08A', '#F8D25F', '#F2C250'] },
  { ago: 8, hexes: ['#CBB8F0', '#A996E0', '#8A7BC8'] },
  { ago: 11, hexes: ['#FFC4D6', '#F79CC0', '#E779A8'] },
  { ago: 15, hexes: ['#9EE0E0', '#6CC7CF', '#4AA6B8'] },
  { ago: 19, hexes: ['#FFD3B0', '#FFB488', '#F59A6E'] },
  { ago: 24, hexes: ['#DAD7D3', '#C9C5C2'] },
  { ago: 34, hexes: ['#F2A6A0', '#E58B87'] },
  { ago: 38, hexes: ['#A8D8B0', '#7FC09A'] },
  { ago: 45, hexes: ['#9BB6F0', '#7C98E0'] },
  { ago: 52, hexes: ['#F7D9A0', '#EBC07A'] },
  { ago: 60, hexes: ['#E3B6E8', '#C98FD8'] },
  { ago: 365, hexes: ['#FFC9A8', '#F4A582', '#E88C6C'] },
  { ago: 371, hexes: ['#B0D8F0', '#90C4EA'] },
];

const mix = (a, b, k) => a.map((v, i) => v + (b[i] - v) * k);
const css = (c) => `rgb(${c.map((v) => Math.round(Math.max(0, Math.min(1, v)) * 255)).join(',')})`;

function scene(hex, rand, kind) {
  const W = 600, H = 800;
  const c = document.createElement('canvas');
  c.width = W; c.height = H;
  const x = c.getContext('2d');
  const base = hexToRgb(hex);
  const sky = x.createLinearGradient(0, 0, 0, H);
  sky.addColorStop(0, css(mix(base, [1, 1, 1], 0.18)));
  sky.addColorStop(0.7, css(base));
  sky.addColorStop(1, css(mix(base, [0, 0, 0], 0.08)));
  x.fillStyle = sky;
  x.fillRect(0, 0, W, H);
  // 해
  x.fillStyle = css(mix(base, [1, 1, 0.92], 0.55));
  x.beginPath(); x.arc(W * (0.25 + rand() * 0.5), H * (0.18 + rand() * 0.12), 50 + rand() * 30, 0, Math.PI * 2); x.fill();
  // 구름
  x.fillStyle = 'rgba(255,255,255,0.55)';
  for (let i = 0; i < 3; i++) {
    const cx = rand() * W, cy = H * (0.1 + rand() * 0.3);
    for (let k = 0; k < 4; k++) { x.beginPath(); x.ellipse(cx + k * 34 - 50, cy + (k % 2) * 8, 40, 24, 0, 0, Math.PI * 2); x.fill(); }
  }
  if (kind === 'sea') {
    x.fillStyle = css(mix(base, [0.1, 0.2, 0.35], 0.35));
    x.fillRect(0, H * 0.72, W, H * 0.28);
    x.strokeStyle = 'rgba(255,255,255,0.45)';
    x.lineWidth = 3;
    for (let i = 0; i < 6; i++) {
      const y = H * (0.76 + i * 0.04);
      x.beginPath();
      for (let k = 0; k <= W; k += 20) x.lineTo(k, y + Math.sin(k / 30 + i) * 4);
      x.stroke();
    }
  } else {
    for (const [top, k] of [[0.68, 0.22], [0.78, 0.36]]) {
      x.fillStyle = css(mix(base, [0.1, 0.12, 0.08], k));
      x.beginPath(); x.moveTo(0, H);
      for (let px = 0; px <= W; px += 10) x.lineTo(px, H * top + Math.sin(px / 90 + k * 9) * 26 + Math.sin(px / 37) * 8);
      x.lineTo(W, H); x.closePath(); x.fill();
    }
    // 꽃 몇 송이
    const cols = ['#FF8FB1', '#FFD84D', '#FFFFFF', '#B9A6FF'];
    for (let i = 0; i < 14; i++) {
      const fx = rand() * W, fy = H * (0.8 + rand() * 0.18), r = 5 + rand() * 6;
      x.fillStyle = cols[i % cols.length];
      for (let p = 0; p < 5; p++) { const a = (p / 5) * Math.PI * 2; x.beginPath(); x.arc(fx + Math.cos(a) * r, fy + Math.sin(a) * r, r * 0.7, 0, Math.PI * 2); x.fill(); }
      x.fillStyle = '#FFC94D'; x.beginPath(); x.arc(fx, fy, r * 0.5, 0, Math.PI * 2); x.fill();
    }
  }
  return c;
}

/** onProgress(done, total) */
export async function fillSample(store, onProgress = () => {}) {
  const t = now();
  const today = dayKey(t);
  const total = DAYS.reduce((n, d) => n + d.hexes.length, 0);
  let done = 0;
  const entries = [];
  for (const day of DAYS) {
    const key = shiftKey(today, -day.ago);
    const rand = rng(`sample:${key}`);
    const start = dayStart(key);
    let hours = day.hours;
    if (!hours) {
      let h = 8 + rand() * 3;
      hours = day.hexes.map(() => { const v = h; h += 1.2 + rand() * 3; return Math.min(v, 22); });
    }
    let times = hours.map((h) => new Date(new Date(start).setHours(Math.floor(h), Math.round((h % 1) * 60), 0, 0)).getTime());
    if (day.ago === 0) {
      // 오늘은 지금보다 앞선 시각만 — 하루가 방금 시작됐으면 조금씩 앞으로 당긴다.
      const room = Math.max(10 * 60e3, t - start - 5 * 60e3);
      times = day.hexes.map((_, i) => start + room * ((i + 1) / (day.hexes.length + 0.5)));
    }
    for (let i = 0; i < day.hexes.length; i++) {
      const c = scene(day.hexes[i], rand, (day.ago + i) % 3 === 1 ? 'sea' : 'hills');
      const prepared = await prepareCanvas(c);
      entries.push({
        moment: {
          id: `sample-${key}-${i}`,
          capturedAt: times[i],
          addedAt: null,
          batchID: null,
          colorHex: prepared.colorHex,
          source: 'sample',
        },
        full: prepared.full,
        thumb: prepared.thumb,
      });
      done++;
      onProgress(done, total);
    }
  }
  await store.add(entries);
  // 그저께까지는 이미 받은 하루로 — 어제만 남겨 두면 홈에 들어서자마자 증정이 뜬다.
  store.setGiftedFloor(shiftKey(today, -2));
  store.emit();
}
