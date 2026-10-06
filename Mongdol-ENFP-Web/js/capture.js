// 담기 — HomeShell 의 좌→우 스와이프 + CaptureScreen. 홈에 셔터는 없다(앱은 「보러」 오는 곳).
// 찍는 순간 색을 보여 주지 않는다. 확인 문구와 사진 더미만.
import { h, layers, toast, uuid, stage } from './dom.js';
import { store } from './store.js';
import { prepare, prepareCanvas, exifDate } from './images.js';
import { T } from './copy.js';
import { flowerSVG, burst } from './flowers.js';
import { now } from './clock.js';
import { meta } from './db.js';

const COMMIT_DISTANCE = 0.42;
const COMMIT_VELOCITY = 420;

export function createCapture({ onSwiped } = {}) {
  const homeWrap = document.getElementById('home-wrap');
  const cam = document.getElementById('camera');
  let progress = 0;
  let stream = null;
  let session = [];
  let busy = false;

  const video = h('video', { class: 'cam-video', playsinline: true, muted: true, autoplay: true });
  video.muted = true;
  const shy = h('div', { class: 'cam-shy' },
    h('span', { class: 'cam-shy-flower', html: flowerSVG({ size: 54, kind: 'daisy', color: '#FFD6E4', center: '#FFD84D' }) }),
    h('p', { class: 'cam-shy-title' }, T.cameraShy),
    h('p', { class: 'cam-shy-hint' }, T.cameraShyHint));
  const confirmEl = h('div', { class: 'cam-confirm', role: 'status', 'aria-live': 'polite' });
  const flash = h('div', { class: 'cam-flash' });
  const closeBtn = h('button', { class: 'pill-close cam-close', onClick: () => close() }, T.close);
  const windowEl = h('div', { class: 'cam-window' }, video, shy, flash, confirmEl, closeBtn);

  const shootInput = h('input', { type: 'file', accept: 'image/*', capture: 'environment', class: 'sr-only', 'aria-hidden': 'true', tabindex: '-1' });
  const pickInput = h('input', { type: 'file', accept: 'image/*', multiple: true, class: 'sr-only', 'aria-hidden': 'true', tabindex: '-1' });
  const libraryBtn = h('button', { class: 'cam-side-btn', 'aria-label': '앨범에서 골라 담기', onClick: () => pickInput.click() },
    h('span', { class: 'cam-lib-icon' }), h('span', null, '앨범'));
  const shutter = h('button', { class: 'cam-shutter', 'aria-label': '찰칵 담기', html: `<span class="cam-shutter-core">${flowerSVG({ size: 40, kind: 'five', color: '#FFFFFF', center: '#FFD84D' })}</span>` });
  const pile = h('button', { class: 'cam-pile', 'aria-label': '이번에 담은 사진' });
  const controls = h('div', { class: 'cam-controls' }, libraryBtn, shutter, pile);
  const backHint = h('div', { class: 'cam-back-hint', 'aria-hidden': 'true' }, `← ${T.cameraBack}`);
  cam.replaceChildren(windowEl, controls, backHint, shootInput, pickInput);

  pile.addEventListener('click', () => toast(T.viewerLocked));

  // 창은 「폭 − 20 · 비율 560:370」, 높이가 모자라면 창이 줄고 컨트롤 자리는 그대로(원본 DESIGN §4.5).
  const layoutWindow = () => {
    const W = stage().clientWidth, H = stage().clientHeight;
    let w = W - 20, hh = (w * 560) / 370;
    const maxH = H - 18 - 190;
    if (hh > maxH) { hh = Math.max(200, maxH); w = (hh * 370) / 560; }
    cam.style.setProperty('--cam-w', `${w}px`);
    cam.style.setProperty('--cam-h', `${hh}px`);
  };

  const apply = (p, animate) => {
    progress = p;
    layoutWindow();
    const w = stage().clientWidth;
    const tr = animate ? 'transform .42s cubic-bezier(.2,1.1,.3,1)' : 'none';
    homeWrap.style.transition = tr;
    cam.style.transition = tr;
    homeWrap.style.transform = `translateX(${p * w}px)`;
    cam.style.transform = `translateX(${(p - 1) * w}px)`;
    cam.classList.toggle('live', p > 0.001);
  };

  let shyTimer = 0;
  let starting = null;
  let closeTimer = 0;
  async function startCamera() {
    if (stream || starting) return;
    if (!navigator.mediaDevices?.getUserMedia) { cam.classList.add('no-camera'); return; }
    // 권한 창을 기다리는 동안 까만 창만 보이지 않게 — 조금 지나도 안 켜지면 「앨범·셔터로도 담겨요」 안내.
    clearTimeout(shyTimer);
    shyTimer = setTimeout(() => { if (!stream) cam.classList.add('no-camera'); }, 1800);
    starting = navigator.mediaDevices.getUserMedia({ video: { facingMode: { ideal: 'environment' }, width: { ideal: 1920 }, height: { ideal: 1440 } }, audio: false });
    try {
      const got = await starting;
      // 권한 창을 기다리는 사이 카메라를 닫았으면 받은 스트림을 바로 끈다.
      if (progress < 0.001) { got.getTracks().forEach((t) => t.stop()); return; }
      stream = got;
      // iOS 는 백그라운드에 다녀오면 트랙을 끝내 버린다 — 끝난 스트림을 붙들고 있으면 멈춘·까만 프레임이 찍힌다.
      for (const t of got.getVideoTracks()) t.addEventListener('ended', () => { if (stream === got) stopCamera(); });
      video.srcObject = stream;
      await video.play().catch(() => {});
      cam.classList.remove('no-camera');
    } catch {
      stream = null;
      cam.classList.add('no-camera');
    } finally {
      starting = null;
    }
  }

  function stopCamera() {
    if (stream) stream.getTracks().forEach((t) => t.stop());
    stream = null;
    video.srcObject = null;
  }

  const live = () => !!stream && stream.getVideoTracks().some((t) => t.readyState === 'live') && video.videoWidth > 0;

  document.addEventListener('visibilitychange', () => {
    if (document.hidden) stopCamera();
    else if (layers.has('camera') && progress > 0.001) startCamera();
  });

  function open() {
    // 닫히는 중(0.44초)에 다시 열면 닫기를 취소하고 그대로 연다.
    if (closeTimer) { clearTimeout(closeTimer); closeTimer = 0; }
    if (!layers.has('camera')) { layers.add('camera'); resetSession(); }
    apply(1, true);
    startCamera();
    if (!meta.get('swiped', false)) { meta.set('swiped', true); onSwiped?.(); }
  }

  function close() {
    apply(0, true);
    clearTimeout(closeTimer);
    closeTimer = setTimeout(() => {
      closeTimer = 0;
      if (progress === 0) { stopCamera(); layers.remove('camera'); resetSession(); }
    }, 440);
  }

  // 왼쪽 가장자리에서 오른쪽으로 쓸면 카메라가 따라 들어온다. 카메라에선 반대로.
  let drag = null;
  stage().addEventListener('pointerdown', (e) => {
    const r = stage().getBoundingClientRect();
    const x = e.clientX - r.left;
    const onCam = layers.has('camera');
    if (!onCam && (x > 26 || layers.blocking)) return;
    if (onCam && (e.target.closest('.cam-controls') || e.target.closest('button'))) return;
    drag = { x0: e.clientX, y0: e.clientY, id: e.pointerId, from: onCam ? 1 : 0, axis: null, lastX: e.clientX, lastT: performance.now(), v: 0 };
  });
  stage().addEventListener('pointermove', (e) => {
    if (!drag || e.pointerId !== drag.id) return;
    const dx = e.clientX - drag.x0, dy = e.clientY - drag.y0;
    if (!drag.axis) {
      if (Math.hypot(dx, dy) < 12) return;
      drag.axis = Math.abs(dx) > Math.abs(dy) * 1.4 ? 'x' : 'y';
      if (drag.axis === 'y') { drag = null; return; }
      if (drag.from === 0) {
        if (closeTimer) { clearTimeout(closeTimer); closeTimer = 0; }
        if (!layers.has('camera')) { layers.add('camera'); resetSession(); }
        startCamera();
      }
      try { stage().setPointerCapture(e.pointerId); } catch { /* 무시 */ }
    }
    const w = stage().clientWidth;
    const t = performance.now();
    drag.v = ((e.clientX - drag.lastX) / Math.max(1, t - drag.lastT)) * 1000;
    drag.lastX = e.clientX; drag.lastT = t;
    apply(Math.min(1, Math.max(0, drag.from + dx / w)), false);
  });
  const end = (e) => {
    if (!drag || e.pointerId !== drag.id) return;
    const d = drag;
    drag = null;
    if (d.axis !== 'x') return;
    const opening = d.from === 0;
    const commit = opening
      ? progress > COMMIT_DISTANCE || d.v > COMMIT_VELOCITY
      : progress < 1 - COMMIT_DISTANCE || d.v < -COMMIT_VELOCITY;
    if (opening && commit) {
      apply(1, true);
      if (!meta.get('swiped', false)) { meta.set('swiped', true); onSwiped?.(); }
    } else if (opening) {
      close();
    } else if (commit) {
      close();
    } else {
      apply(1, true);
    }
  };
  stage().addEventListener('pointerup', end);
  stage().addEventListener('pointercancel', end);

  function confirm(text) {
    confirmEl.textContent = text;
    confirmEl.classList.remove('show');
    void confirmEl.offsetWidth;
    confirmEl.classList.add('show');
  }

  function resetSession() {
    for (const u of session) URL.revokeObjectURL(u);
    session = [];
    renderPile();
  }

  function renderPile() {
    pile.replaceChildren();
    const shown = session.slice(-4);
    shown.forEach((u, i) => {
      const card = h('span', { class: 'pile-card', style: { transform: `rotate(${(i - shown.length + 1) * 5 + 3}deg)` } }, h('img', { src: u, alt: '' }));
      pile.append(card);
    });
    if (session.length) pile.append(h('span', { class: 'pile-count num' }, String(session.length)));
    pile.classList.toggle('empty', !session.length);
  }

  const fileSig = (f) => `${f.name}|${f.size}|${f.lastModified}`;
  // iOS 사진 선택기는 고를 때마다 lastModified 를 새로 줄 수 있어서 내용으로도 한 번 더 본다.
  const contentSig = async (f) => {
    try {
      const d = await crypto.subtle.digest('SHA-256', await f.arrayBuffer());
      return 'sha256:' + [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, '0')).join('');
    } catch { return null; }
  };

  /** 한 장씩 담는다 — 한 장이 실패해도(HEIC 디코드 등) 나머지는 담고, 실패·중복 개수를 돌려준다. */
  async function addShots(items, source) {
    const batchID = source === 'library' ? uuid() : null;
    const entries = [];
    const seen = new Set();
    let failed = 0, dupes = 0;
    for (const it of items) {
      const sig = it.file ? fileSig(it.file) : null;
      const csig = it.file ? await contentSig(it.file) : null;
      const sigs = [sig, csig].filter(Boolean);
      if (sigs.some((x) => seen.has(x) || store.hasFileSig(x))) { dupes++; continue; }
      sigs.forEach((x) => seen.add(x));
      try {
        const prepared = it.canvas ? await prepareCanvas(it.canvas) : await prepare(it.file);
        const t = now();
        let capturedAt = t;
        if (source === 'library') {
          const shotAt = await exifDate(it.file);
          const lm = it.file.lastModified;
          capturedAt = shotAt ?? (lm > 0 && lm <= t ? lm : t);
        }
        entries.push({
          moment: {
            id: uuid(),
            // 카메라로 찍은 건 지금 시각. 파일로 들어온 건 전부 addedAt 을 채운다 —
            // 마무리한 뒤 넣은 사진이 이미 열린 조약돌 색을 바꾸지 않게(pebbleMoments 가 addedAt 으로 가른다).
            capturedAt,
            addedAt: it.file ? t : null,
            batchID,
            colorHex: prepared.colorHex,
            source,
            fileSig: sig,
            contentSig: csig,
          },
          full: prepared.full,
          thumb: prepared.thumb,
        });
      } catch (err) {
        console.warn('[몽돌] 사진 한 장을 못 읽었어요', err);
        failed++;
      }
    }
    try {
      await store.add(entries);
    } catch (err) {
      console.warn('[몽돌] 저장 실패', err);
      return { added: 0, failed: failed + entries.length, dupes, storage: true };
    }
    for (const e of entries) session.push(URL.createObjectURL(e.thumb));
    renderPile();
    const last = pile.lastElementChild?.previousElementSibling || pile.lastElementChild;
    if (entries.length) {
      last?.animate([{ transform: 'translate(-90px, 10px) scale(.5)', opacity: 0 }, { transform: last.style.transform, opacity: 1 }],
        { duration: 420, easing: 'cubic-bezier(.3,1.4,.5,1)' });
    }
    return { added: entries.length, failed, dupes, storage: false };
  }

  function report(r) {
    if (r.added) confirm(r.added > 1 ? T.capturedMany(r.added) : T.captured);
    else confirmEl.classList.remove('show');
    if (r.storage) toast('앗, 저장 공간이 모자라서 못 담았어요');
    else if (r.failed && r.dupes) toast(`${r.failed}장은 못 읽었고, ${r.dupes}장은 이미 담긴 사진이에요`);
    else if (r.failed) toast(`${r.failed}장은 못 읽었어요. 나머지는 잘 담았어요!`);
    else if (r.dupes) toast(r.added ? `${r.dupes}장은 이미 담긴 사진이라 건너뛰었어요` : '이미 담긴 사진이에요!');
  }

  shutter.addEventListener('click', async () => {
    if (busy) return;
    if (!live()) { stopCamera(); shootInput.click(); return; }
    busy = true;
    const c = document.createElement('canvas');
    const vw = video.videoWidth, vh = video.videoHeight;
    const k = Math.min(1, 1600 / Math.max(vw, vh));
    c.width = Math.round(vw * k); c.height = Math.round(vh * k);
    c.getContext('2d').drawImage(video, 0, 0, c.width, c.height);
    flash.classList.remove('go'); void flash.offsetWidth; flash.classList.add('go');
    burst(controls, controls.clientWidth / 2, 37, { count: 7, distance: 60 });
    try {
      report(await addShots([{ canvas: c }], 'app'));
    } catch (err) {
      console.warn(err);
      toast('앗, 이번 건 못 담았어요. 한 번만 더!');
    } finally { busy = false; }
  });

  const fromInput = (input, source) => async () => {
    const files = [...input.files];
    input.value = '';
    if (!files.length || busy) return;
    busy = true;
    if (source === 'app') { flash.classList.remove('go'); void flash.offsetWidth; flash.classList.add('go'); }
    confirm('담는 중…');
    try {
      report(await addShots(files.map((file) => ({ file })), source));
    } catch (err) {
      console.warn(err);
      confirmEl.classList.remove('show');
      toast('앗, 이번 건 못 담았어요. 한 번만 더!');
    } finally { busy = false; }
  };
  shootInput.addEventListener('change', fromInput(shootInput, 'app'));
  pickInput.addEventListener('change', fromInput(pickInput, 'library'));

  apply(0, false);
  window.addEventListener('resize', () => apply(progress, false));
  return { open, close, isOpen: () => progress > 0.5 };
}
