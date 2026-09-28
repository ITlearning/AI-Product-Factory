/**
 * ② 영상 확정 — **곡당 한 번만 뜬다.**
 *
 * 검색 호출이 *사용자 수*가 아니라 *곡 수*에 비례하게 만드는 장치다.
 * 그 곡이 이미 있으면 서버가 영상을 갖고 있으므로 여기 안 온다.
 *
 * ## 키가 없어도 화면이 돈다
 * `YOUTUBE_API_KEY` 가 없거나, 하루 100회 쿼터가 끝났거나, 구글이 403을 주면
 * 후보 목록 자리에 **"유튜브 링크를 직접 넣어주세요"만** 뜬다.
 * 그래서 구글 클라우드 행정이 출시를 막지 않는다.
 *
 * 직접 링크 입력은 키가 있든 없든 **항상 열려 있다.** 90일 미사용 차단 같은 일이 언제든 생긴다.
 */

import { el, replace, artwork } from '../dom.js';
import { searchVideos, checkVideoUrl } from '../../client/api.js';
import { getDraft, setDraft } from '../../client/draft.js';
import { songHead } from '../components.js';
import { go } from '../router.js';

/**
 * @param {HTMLElement} root
 */
export function videoScreen(root) {
  const draft = getDraft();
  if (!draft?.song) return go('/start');

  const candidates = el('div', {});
  const manual = manualBlock();

  replace(
    root,
    el('div', { className: 'screen shell stack' }, [
      songHead(draft.song, { size: 300 }),
      el('p', { className: 'tertiary', text: '이 곡을 들을 영상을 하나 정해주세요. 다음 사람도 이 영상으로 듣게 돼요.' }),
      candidates,
      manual,
    ]),
  );

  const query = [draft.song.title, draft.song.artist].filter(Boolean).join(' ');
  replace(candidates, el('p', { className: 'loading', text: '영상을 찾는 중이에요…' }));

  searchVideos(query)
    .then((data) => {
      if (!data.available) {
        replace(candidates, el('p', { className: 'muted', text: unavailableCopy(data.reason) }));
        return;
      }
      if (data.videos.length === 0) {
        replace(candidates, el('p', { className: 'muted', text: '이 곡의 영상을 못 찾았어요.' }));
        return;
      }
      replace(
        candidates,
        el('p', { className: 'tertiary', text: '맞는 영상을 골라주세요.' }),
        el('ul', { className: 'hits' }, data.videos.map((v) => el('li', {}, [videoHit(v)]))),
      );
    })
    .catch(() => {
      replace(candidates, el('p', { className: 'muted', text: unavailableCopy('error') }));
    });

  /**
   * 폴백 문구. 사용자에게 "쿼터"나 "API 키" 같은 말을 하지 않는다 —
   * 그건 우리 사정이지 이 사람이 알 필요가 있는 게 아니다.
   */
  function unavailableCopy(reason) {
    if (reason === 'quota') return '오늘은 자동 찾기를 다 썼어요. 유튜브 링크를 직접 넣어주세요.';
    return '유튜브 링크를 직접 넣어주세요.';
  }

  function videoHit(video) {
    const btn = el('button', { className: 'hit', type: 'button' }, [
      artwork(video.thumbnail, 'hit__art'),
      el('span', {}, [
        el('span', { className: 'hit__title', text: video.title }),
        el('br'),
        el('span', { className: 'hit__sub', text: video.channel }),
      ]),
    ]);
    btn.addEventListener('click', () => pick(video.videoId));
    return btn;
  }

  /** 직접 링크. 붙여넣으면 **제목을 보여준다** — 엉뚱한 영상인지 본인이 알아볼 유일한 방법이다. */
  function manualBlock() {
    const input = el('input', {
      className: 'field',
      type: 'url',
      placeholder: 'https://youtu.be/…',
      attrs: { 'aria-label': '유튜브 링크', inputmode: 'url', autocomplete: 'off' },
    });
    const preview = el('div', {});
    const submit = el('button', { className: 'btn btn--block', type: 'submit', text: '이 링크로 하기' });

    const form = el('form', { className: 'stack' }, [
      el('p', { className: 'section-title', text: '유튜브 링크 직접 넣기' }),
      input,
      submit,
      preview,
    ]);

    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      const raw = input.value.trim();
      if (!raw) return;
      replace(preview, el('p', { className: 'loading', text: '확인하는 중이에요…' }));
      try {
        const info = await checkVideoUrl(raw);
        if (!info.alive) {
          replace(preview, el('p', { className: 'muted danger', text: '이 영상은 지금 볼 수 없어요.' }));
          return;
        }
        const confirm = el('button', { className: 'btn btn--primary btn--block', type: 'button', text: '이 영상이 맞아요' });
        confirm.addEventListener('click', () => pick(info.videoId, info));
        replace(
          preview,
          el('div', { className: 'hit' }, [
            artwork(info.thumbnail, 'hit__art'),
            el('span', {}, [
              el('span', { className: 'hit__title', text: info.title ?? '(제목을 못 읽었어요)' }),
              el('br'),
              el('span', { className: 'hit__sub', text: info.channel ?? '' }),
            ]),
          ]),
          confirm,
        );
      } catch (err) {
        replace(preview, el('p', { className: 'muted danger', text: err.message }));
      }
    });

    return form;
  }

  /**
   * 영상을 정한다.
   *
   * `source='youtube'` 곡은 **영상 ID가 곡의 열쇠 그 자체**라, 여기서 곡명·가수명을 마저 받는다.
   */
  function pick(videoId, info) {
    const song = { ...draft.song, youtubeVideoId: videoId };

    if (song.source === 'youtube') {
      setDraft({ song });
      return go('/name');
    }
    setDraft({ song });
    go('/write');
  }
}
