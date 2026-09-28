/**
 * ⑦ 내 갈피.
 *
 * 공개·비공개를 모두 보여주고 **`removed` 된 글도 "숨겨진 글"로 표시한다** —
 * 조용히 사라지면 사용자가 더 혼란스럽다.
 *
 * 복구 코드를 여기서 언제든 다시 볼 수 있다. ③ 직후에 "나중에 할게요"를 누른 사람의 종착지다.
 */

import { el, replace } from '../dom.js';
import { songHead, memoryBlock, emptyState } from '../components.js';
import { getMine } from '../../client/api.js';
import { readKey, restoreKey } from '../../client/device.js';

/**
 * @param {HTMLElement} root
 */
export async function mineScreen(root) {
  const key = readKey();

  if (!key) {
    // 이 기기에 글이 없는 사람. 다른 기기에서 쓴 사람일 수도 있다.
    replace(root, el('div', { className: 'screen shell stack' }, [
      emptyState({
        line: '아직 이 기기에 적어둔 기억이 없어요.',
        action: { label: '기억 적기', href: '#/start' },
      }),
      restoreForm(),
    ]));
    return;
  }

  replace(root, el('p', { className: 'loading', text: '불러오는 중이에요…' }));

  let memories;
  try {
    ({ memories } = await getMine());
  } catch (err) {
    replace(root, el('div', { className: 'screen shell stack' }, [
      el('p', { className: 'muted', text: err.message }),
      restoreForm(),
    ]));
    return;
  }

  if (memories.length === 0) {
    replace(root, el('div', { className: 'screen shell stack' }, [
      emptyState({ line: '아직 적어둔 기억이 없어요.', action: { label: '기억 적기', href: '#/start' } }),
      recoveryBlock(key),
      restoreForm(),
    ]));
    return;
  }

  replace(
    root,
    el('div', { className: 'screen shell' }, [
      el('div', {}, memories.map(mineCard)),
      recoveryBlock(key),
      restoreForm(),
    ]),
  );
}

/**
 * 내 글 한 편. 남의 글과 달리 **상태를 같이 보여준다.**
 */
function mineCard(m) {
  const song = {
    id: m.song_id,
    title: m.title,
    artist: m.artist,
    artwork_url: m.artwork_url,
  };

  const badges = [];
  if (!m.is_public) badges.push('나만 보는 글');
  if (m.status === 'hidden') badges.push('신고로 내려간 글');
  if (m.status === 'removed') badges.push('운영자가 내린 글');

  return el('section', { className: 'card' }, [
    songHead(song, { as: 'a', href: `#/song/${m.song_id}`, size: 150 }),
    badges.length > 0
      ? el('p', { className: 'tertiary', text: badges.join(' · ') })
      : null,
    el('div', { className: 'card__memories' }, [
      // 내 글에 내가 ♡를 누르는 화면은 필요 없다.
      memoryBlock(m, { clamp: true, showHeart: false }),
    ]),
  ]);
}

/**
 * 복구 코드. 경고가 아니라 안내다.
 *
 * **대가를 숨기지 않는다** — 코드가 곧 키라서 남에게 알려주면 그 사람이 내 글을 지울 수 있다.
 */
function recoveryBlock(key) {
  const copy = el('button', { className: 'btn', type: 'button', text: '복사하기' });
  copy.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(key);
      copy.textContent = '복사했어요';
    } catch {
      copy.textContent = '길게 눌러 복사해주세요';
    }
  });

  return el('details', { className: 'recovery' }, [
    el('summary', { className: 'sheet__body', text: '다른 기기에서 꺼내기' }),
    el('p', { className: 'sheet__body', text: '이 코드를 적어두면 다른 기기에서도 이 글들을 꺼낼 수 있어요. 남에게 알려주면 그 사람도 지울 수 있으니 혼자만 보세요.' }),
    el('p', { className: 'recovery__code', text: key }),
    el('div', { className: 'sheet__actions' }, [copy]),
  ]);
}

/**
 * 복구 코드 입력. 하이픈을 빼먹거나 소문자로 써도 받는다 —
 * 여기서 까다롭게 굴면 코드가 있는데도 못 돌아오는 사람이 생긴다.
 */
function restoreForm() {
  const input = el('input', {
    className: 'field',
    placeholder: '갈피-0000-0000-0000',
    attrs: { 'aria-label': '복구 코드', autocomplete: 'off', autocapitalize: 'characters' },
  });
  const status = el('p', { className: 'tertiary' });
  const form = el('form', { className: 'stack' }, [
    el('p', { className: 'section-title', text: '다른 기기에서 쓴 글 꺼내기' }),
    input,
    el('button', { className: 'btn btn--block', type: 'submit', text: '꺼내기' }),
    status,
  ]);

  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const restored = restoreKey(input.value);
    if (!restored) {
      status.textContent = '코드를 다시 확인해주세요.';
      status.className = 'tertiary danger';
      return;
    }
    // 같은 화면을 다시 그린다 — 이제 키가 있으므로 글이 뜬다.
    location.reload();
  });

  return el('details', {}, [
    el('summary', { className: 'sheet__body', text: '복구 코드가 있어요' }),
    form,
  ]);
}
