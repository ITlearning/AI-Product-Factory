/**
 * ⑥ 곡 상세 — **이 제품에서 소리가 나는 유일한 화면.**
 *
 * 플레이어를 상단에 고정하고 기억만 스크롤시킨다. 그러면 RMF 세 조항을 전부 통과하면서
 * "노래가 흐르는 동안 남의 기억을 읽어 내려간다"는 원래 목적이 그대로 지켜진다.
 *
 * | 조항 | 어떻게 지키나 |
 * |---|---|
 * | 플레이어 최소 200×200px | 폭 전체 16:9 + `min-height: 200px` (CSS) |
 * | 소리만 분리 금지 | 표준 iframe 그대로. 영상을 숨기지 않는다 |
 * | 플레이어 위에 덮기 금지 | 시트·헤더가 플레이어 **위에** 오지 않는다. 기억은 아래로만 흐른다 |
 * | 자동재생 조건 | 자동재생을 아예 안 켠다. 사용자가 누른다 |
 *
 * **v1은 검색엔진에 열지 않는다.** "밤편지 가사 의미"로 들어온 사람이 글 3편을 보면
 * 유튜브 댓글 수만 개와 바로 비교된다. 곡당 평균 5편을 넘으면 그때 연다.
 *
 * 진입할 때 oEmbed 로 영상 생존 확인을 하지 않는다 — 가장 자주 열리는 화면에 외부 왕복이
 * 매번 붙는 값이 크고, 죽은 영상은 iframe 이 알아서 에러를 보여준다.
 */

import { el, replace } from '../dom.js';
import { songHead, memoryBlock, emptyState } from '../components.js';
import { getSong, report } from '../../client/api.js';
import { setNoindex } from '../head.js';

/**
 * @param {HTMLElement} root
 * @param {string} songId
 */
export async function songScreen(root, songId) {
  setNoindex(true);
  replace(root, el('p', { className: 'loading', text: '불러오는 중이에요…' }));

  let data;
  try {
    data = await getSong(songId);
  } catch (err) {
    replace(root, el('div', { className: 'screen shell' }, [
      el('p', { className: 'muted', text: err.message }),
    ]));
    return;
  }

  const { song, memories } = data;

  const player = el('div', { className: 'player' }, [
    el('iframe', {
      className: 'player__frame',
      src: `https://www.youtube-nocookie.com/embed/${song.youtube_video_id}`,
      attrs: {
        // 스크린리더가 "프레임"이라고만 읽지 않게 한다.
        title: `${song.title} — ${song.artist} 영상`,
        allow: 'accelerometer; clipboard-write; encrypted-media; gyroscope; picture-in-picture',
        allowfullscreen: 'true',
        referrerpolicy: 'strict-origin-when-cross-origin',
        loading: 'eager',
      },
    }),
    el('p', {
      className: 'player__count',
      text: memories.length > 0 ? `기억 ${memories.length}편 · 아래만 스크롤됩니다` : '',
    }),
  ]);

  const body =
    memories.length === 0
      ? emptyState({
          line: '아직 이 곡의 기억이 없어요.\n첫 사람이 되어볼래요?',
          action: { label: '기억 적기', href: `#/write?songId=${song.id}` },
        })
      : el('div', {}, [
          el('div', { className: 'card__memories' },
            // 상세에서는 접지 않는다. 여기 온 사람은 읽으러 온 사람이다.
            memories.map((m) => memoryBlock(m, { clamp: false })),
          ),
          el('a', {
            className: 'card__add',
            href: `#/write?songId=${song.id}`,
            text: '나도 적기',
          }),
        ]);

  replace(
    root,
    el('div', { className: 'screen shell' }, [
      player,
      el('div', { style: 'margin: 12px 0 16px' }, [songHead(song, { size: 150 })]),
      body,
      reportRow(song),
    ]),
  );
}

/**
 * "영상이 곡과 달라요" — `reports.song_id` 경로.
 *
 * 곡 등록 시 영상 검증을 1회로 올리지 않은 대신 열어둔 길이다.
 * 신고가 반복되면 그때 검증을 앞으로 당긴다.
 */
function reportRow(song) {
  const btn = el('button', {
    className: 'empty__escape',
    type: 'button',
    text: '영상이 이 곡과 달라요',
  });
  btn.addEventListener('click', async () => {
    btn.disabled = true;
    try {
      await report({ songId: song.id, reason: '영상이 곡과 다름' });
      btn.textContent = '알려주셔서 고마워요';
    } catch (err) {
      btn.textContent = err.message;
      btn.disabled = false;
    }
  });
  return el('div', { style: 'text-align:center' }, [btn]);
}
