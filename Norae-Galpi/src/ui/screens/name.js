/**
 * ② 뒤에 붙는 작은 화면 — iTunes 에 없는 곡의 곡명·가수명을 직접 받는다.
 *
 * 드라이런에서 **20곡 중 1곡이 iTunes 카탈로그에 없었다**(무한도전 「그래 우리 함께」).
 * 예능 프로젝트 곡, 오래된 곡, 유통이 끊긴 곡, 인디 자체발매가 전부 여기 걸리고,
 * **하필 그런 곡이 추억이 진한 소재**다.
 *
 * 이 곡들은 `title_key`를 서버가 us 제목에서 만들 수 없으므로 여기서 만든 값을 보낸다.
 */

import { el, replace } from '../dom.js';
import { getDraft, setDraft } from '../../client/draft.js';
import { go } from '../router.js';
// 서버와 **같은 함수**를 그대로 쓴다. src/itunes.js 에는 node 의존이 없어 브라우저에서 돈다.
import { titleKey } from '../../itunes.js';

/**
 * @param {HTMLElement} root
 */
export function nameScreen(root) {
  const draft = getDraft();
  if (!draft?.song?.youtubeVideoId) return go('/start');

  const title = el('input', {
    className: 'field',
    value: draft.song.title ?? '',
    attrs: { 'aria-label': '곡 제목', autocomplete: 'off' },
  });
  const artist = el('input', {
    className: 'field',
    value: draft.song.artist ?? '',
    placeholder: '가수나 팀 이름',
    attrs: { 'aria-label': '가수', autocomplete: 'off' },
  });
  const submit = el('button', { className: 'btn btn--primary btn--block', type: 'submit', text: '다음' });

  const form = el('form', { className: 'stack' }, [
    el('p', { className: 'muted', text: '이 곡의 이름을 알려주세요. 카드에 이대로 보여요.' }),
    title,
    artist,
    submit,
  ]);

  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const t = title.value.trim();
    const a = artist.value.trim();
    if (!t || !a) return;
    setDraft({
      song: { ...draft.song, title: t, artist: a, titleKey: titleKey(t) },
    });
    go('/write');
  });

  replace(root, el('div', { className: 'screen shell' }, [form]));
  queueMicrotask(() => title.focus());
}
