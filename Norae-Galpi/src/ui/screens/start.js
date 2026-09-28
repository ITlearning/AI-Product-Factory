/**
 * ① 온보딩 — 곡 검색.
 *
 * ## 화면에 못 박힌 두 가지
 * - **검색 결과에 자동 선택이 없다.** 첫 항목이 미리 선택된 상태로 그려지면 안 된다
 * - **"찾는 곡이 없어요"를 결과가 있을 때도 항상 보여준다.** 0건일 때만 뜨면 오답 경로를 못 막는다
 *
 * 이유 — iTunes에 없는 곡을 검색하면 빈손으로 돌아오지 않고 **그럴듯한 오답**이 온다.
 * 「그래 우리 함께」로 검색하면 방탄소년단 봄날이 온다. 사용자가 확인하지 않고 넘어가면
 * 그 기억이 봄날에 붙고, 그 곡의 첫 사람이면 **유튜브 영상까지 봄날로 고정된다.**
 */

import { el, replace, artwork } from '../dom.js';
import { searchSongs } from '../../client/api.js';
import { setDraft } from '../../client/draft.js';
import { go } from '../router.js';

/**
 * @param {HTMLElement} root
 */
export function startScreen(root) {
  const input = el('input', {
    className: 'field',
    type: 'search',
    placeholder: '노래 제목이나 가수',
    attrs: { 'aria-label': '노래 검색', enterkeyhint: 'search', autocomplete: 'off' },
  });

  const results = el('div', {});

  const form = el('form', { className: 'stack' }, [
    input,
    el('button', { className: 'btn btn--primary btn--block', type: 'submit', text: '찾기' }),
  ]);

  form.addEventListener('submit', (e) => {
    e.preventDefault();
    run(input.value.trim());
  });

  replace(
    root,
    el('div', { className: 'screen shell stack' }, [
      el('p', { className: 'muted', text: '추억이 있는 노래가 있으세요?' }),
      form,
      results,
    ]),
  );

  queueMicrotask(() => input.focus());

  async function run(q) {
    if (!q) return;
    replace(results, el('p', { className: 'loading', text: '찾는 중이에요…' }));
    try {
      const { candidates } = await searchSongs(q);
      render(q, candidates ?? []);
    } catch (err) {
      replace(results, el('p', { className: 'loading', text: err.message }), manualEntry(q));
    }
  }

  function render(q, candidates) {
    const list = el('ul', { className: 'hits' }, candidates.map((c) => el('li', {}, [hit(c)])));

    replace(
      results,
      candidates.length === 0
        ? el('p', { className: 'muted', text: '이 이름으로는 못 찾았어요.' })
        : el('p', { className: 'tertiary', text: '맞는 곡을 골라주세요.' }),
      list,
      // 결과가 있어도 항상 띄운다. 이게 오답 경로를 막는 유일한 장치다.
      manualEntry(q),
    );
  }

  /**
   * 후보 하나. **미리 선택된 상태가 없다** — 누르는 것이 곧 선택이다.
   */
  function hit(candidate) {
    const btn = el('button', { className: 'hit', type: 'button' }, [
      artwork(candidate.artworkUrl, 'hit__art', 150),
      el('span', {}, [
        el('span', { className: 'hit__title', text: candidate.title }),
        el('br'),
        el('span', { className: 'hit__sub', text: candidate.artist }),
      ]),
    ]);

    btn.addEventListener('click', () => {
      setDraft({
        song: {
          source: 'itunes',
          itunesArtistId: candidate.artistId,
          itunesTrackId: candidate.trackId,
          titleKey: candidate.titleKey,
          title: candidate.title,
          artist: candidate.artist,
          artworkUrl: candidate.artworkUrl,
        },
      });
      // ②는 곡당 한 번만 뜬다 — 그 곡이 이미 있으면 서버가 영상을 갖고 있다.
      go('/video');
    });

    return btn;
  }

  /** "찾는 곡이 없어요" — 유튜브 영상 ID를 대체 열쇠로 쓰는 경로의 입구. */
  function manualEntry(q) {
    const btn = el('button', {
      className: 'btn btn--block',
      type: 'button',
      text: '찾는 곡이 없어요',
    });
    btn.addEventListener('click', () => {
      setDraft({ song: { source: 'youtube', title: q, artist: '' } });
      go('/video');
    });
    return el('div', { className: 'stack' }, [btn]);
  }
}
