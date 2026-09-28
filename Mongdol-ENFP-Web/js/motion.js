// SwiftUI .spring(response:dampingFraction:) 을 Web Animations 키프레임으로 — 증정 타이밍을 원본과 맞추려고.
import { reduceMotion } from './flowers.js';

export function springCurve(response, damping) {
  const w0 = (2 * Math.PI) / response;
  const z = damping;
  if (z >= 1) return (t) => 1 - Math.exp(-w0 * t) * (1 + w0 * t);
  const wd = w0 * Math.sqrt(1 - z * z);
  return (t) => 1 - Math.exp(-z * w0 * t) * (Math.cos(wd * t) + ((z * w0) / wd) * Math.sin(wd * t));
}

export function settleTime(response, damping) {
  const f = springCurve(response, damping);
  let t = 0;
  for (let i = 0; i < 400; i++) {
    t += 0.01;
    let ok = true;
    for (let k = 0; k < 10; k++) if (Math.abs(1 - f(t + k * 0.01)) > 0.0015) { ok = false; break; }
    if (ok) return t;
  }
  return 4;
}

/** frame(p) 는 진행도 p(0…1, 넘칠 수 있음)를 받아 키프레임 객체를 돌려준다. */
export function animateSpring(el, frame, { response = 0.5, damping = 0.8, delay = 0 } = {}) {
  if (reduceMotion()) {
    const a = el.animate([frame(0), frame(1)], { duration: 250, delay: delay * 1000, easing: 'ease-out', fill: 'both' });
    return a;
  }
  const f = springCurve(response, damping);
  const T = settleTime(response, damping);
  const N = Math.max(24, Math.round(T * 60));
  const frames = [];
  for (let i = 0; i <= N; i++) {
    const t = (i / N) * T;
    frames.push({ ...frame(i === N ? 1 : f(t)), offset: i / N });
  }
  return el.animate(frames, { duration: T * 1000, delay: delay * 1000, easing: 'linear', fill: 'both' });
}

export const wait = (ms) => new Promise((r) => setTimeout(r, ms));
