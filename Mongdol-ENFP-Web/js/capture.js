// 담기 — 탭바 왼쪽 카메라 버튼을 누르면 iOS 선택 메뉴(「사진 찍기 / 사진 보관함」)가 뜬다.
// 웹판은 자체 카메라 화면을 두지 않는다 — Safari 는 들어올 때마다 카메라 권한을 묻고,
// 백그라운드에 다녀오면 멈춘·까만 프레임이 찍혔다. 시스템 카메라가 가볍고 확실하다.
// 찍는 순간 색을 보여 주지 않는다. 확인 문구만.
import { h, toast, uuid } from './dom.js';
import { store } from './store.js';
import { prepare, exifDate } from './images.js';
import { T } from './copy.js';
import { burst } from './flowers.js';
import { now } from './clock.js';

export function createCapture() {
  const input = h('input', { type: 'file', accept: 'image/*', multiple: true, class: 'sr-only', 'aria-hidden': 'true', tabindex: '-1' });
  document.getElementById('stage').append(input);
  let busy = false;

  const fileSig = (f) => `${f.name}|${f.size}|${f.lastModified}`;
  // iOS 사진 선택기는 고를 때마다 lastModified 를 새로 줄 수 있어서 내용으로도 한 번 더 본다.
  const contentSig = async (f) => {
    try {
      const d = await crypto.subtle.digest('SHA-256', await f.arrayBuffer());
      return 'sha256:' + [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, '0')).join('');
    } catch { return null; }
  };

  /** 한 장씩 담는다 — 한 장이 실패해도(HEIC 디코드 등) 나머지는 담고, 실패·중복 개수를 돌려준다. */
  async function addShots(files) {
    const batchID = uuid();
    const entries = [];
    const seen = new Set();
    let failed = 0, dupes = 0;
    for (const file of files) {
      const sig = fileSig(file);
      const csig = await contentSig(file);
      const sigs = [sig, csig].filter(Boolean);
      if (sigs.some((x) => seen.has(x) || store.hasFileSig(x))) { dupes++; continue; }
      sigs.forEach((x) => seen.add(x));
      try {
        const prepared = await prepare(file);
        const t = now();
        // 방금 찍은 사진도 EXIF 촬영 시각이 지금이라 같은 길로 간다.
        const shotAt = await exifDate(file);
        const lm = file.lastModified;
        entries.push({
          moment: {
            id: uuid(),
            capturedAt: shotAt ?? (lm > 0 && lm <= t ? lm : t),
            // 마무리한 뒤 넣은 사진이 이미 열린 조약돌 색을 바꾸지 않게(pebbleMoments 가 addedAt 으로 가른다).
            addedAt: t,
            batchID,
            colorHex: prepared.colorHex,
            source: 'library',
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
      return { added: 0, failed: failed + entries.length, dupes, error: err || new Error('unknown') };
    }
    return { added: entries.length, failed, dupes, error: null };
  }

  function report(r) {
    if (r.error) {
      // 「공간 부족」은 진짜 그럴 때만 — 아니면 오류 이름을 같이 보여 줘야 고칠 수 있다.
      toast(r.error.name === 'QuotaExceededError'
        ? '앗, 저장 공간이 모자라서 못 담았어요'
        : `앗, 사진을 저장하지 못했어요 (${r.error.name || '알 수 없는 오류'})`, 4000);
      return;
    }
    if (r.failed && r.dupes) toast(`${r.failed}장은 못 읽었고, ${r.dupes}장은 이미 담긴 사진이에요`);
    else if (r.failed) toast(r.added ? `${r.failed}장은 못 읽었어요. 나머지는 잘 담았어요!` : '앗, 이 사진은 못 읽었어요');
    else if (r.dupes) toast(r.added ? `${r.dupes}장은 이미 담긴 사진이라 건너뛰었어요` : '이미 담긴 사진이에요!');
    else if (r.added) toast(r.added > 1 ? T.capturedMany(r.added) : T.captured);
    if (r.added) {
      const btn = document.getElementById('tab-camera');
      if (btn && btn.offsetParent) burst(btn, btn.clientWidth / 2, btn.clientHeight / 2, { count: 7, distance: 46 });
    }
  }

  input.addEventListener('change', async () => {
    const files = [...input.files];
    input.value = '';
    if (!files.length || busy) return;
    busy = true;
    toast('담는 중…', 60000);
    try {
      report(await addShots(files));
    } catch (err) {
      console.warn(err);
      toast('앗, 이번 건 못 담았어요. 한 번만 더!');
    } finally { busy = false; }
  });

  // 파일 선택 창은 사용자의 탭 안에서 바로 열어야 한다(비동기 뒤엔 Safari 가 막는다).
  return { open: () => { if (!busy) input.click(); } };
}
