/**
 * ③ 기억 적기 + ④ 공개 확인 + 복구 코드.
 *
 * ## 칩도 예시 글도 두지 않는다
 * 원래는 칩 4개를 두고 첫 칩을 미리 쳐두는 설계였다. 드라이런에서 **글 5편 중 0편이
 * 칩으로 시작하지 않았고**, 기억의 방향이 설계와 반대였다 — 칩은 "이 노래 들으면 → 그때가
 * 떠오른다" 구조였는데 실제는 **"그때 나는 → 이 노래를 들었다"**였다.
 *
 * 칩을 시기형으로 고치는 안도 있었으나 예시 글까지 포함해 전부 폐기했다.
 * **피드가 이미 예시 역할을 한다.** 입력창에 예시를 또 두면 동질화 압력이 두 배가 되고,
 * 이 제품의 가치는 **낯선 사람들의 서로 다른 삶**이라 다 같은 모양이면 피드가 지루해진다.
 *
 * 대신 **곡을 크게 보여준다.** 빈 칸 앞이 아니라 곡 앞에서 쓰는 것이 되게 한다.
 * 시각적 앵커는 글의 방향을 정하지 않는다.
 *
 * ## 글자수를 화면에 두지 않는다
 * 카운트다운도 `n/5000`도 없다. 길게 쓰는 사람을 막지 않는다.
 * 서버에만 폭주 방어용 상한 5,000자가 있다.
 */

import { el, replace } from '../dom.js';
import { songHead, sheet } from '../components.js';
import { SEASONS, SEASON_LABELS, ERAS, ERA_LABELS } from '../labels.js';
import { detectPII } from '../../moderation.js';
import { getDraft, setDraft, clearDraft } from '../../client/draft.js';
import { ensureKey, readKey, hasSeenRecovery, markRecoverySeen } from '../../client/device.js';
import { postMemory, getSong } from '../../client/api.js';
import { go } from '../router.js';

/**
 * @param {HTMLElement} root
 * @param {URLSearchParams} query
 */
export async function writeScreen(root, query) {
  const songId = query.get('songId');
  let draft = getDraft();

  // "나도 적기"로 들어온 경로 — 곡이 이미 있으므로 ①②를 건너뛴다.
  // ②가 곡당 한 번만 뜨는 게 바로 이 경로 덕분이다.
  if (songId) {
    replace(root, el('p', { className: 'loading', text: '곡을 불러오는 중이에요…' }));
    try {
      const { song } = await getSong(songId);
      draft = setDraft({ song: { ...song, existingSongId: song.id }, body: draft?.body ?? '' });
    } catch (err) {
      replace(root, el('div', { className: 'screen shell' }, [
        el('p', { className: 'muted', text: err.message }),
      ]));
      return;
    }
  }

  if (!draft?.song?.youtubeVideoId && !draft?.song?.existingSongId) return go('/start');

  let season = draft.season ?? null;
  let era = draft.era ?? null;

  const body = el('textarea', {
    className: 'field field--body',
    value: draft.body ?? '',
    attrs: { 'aria-label': '기억', placeholder: '' },
  });
  body.addEventListener('input', () => setDraft({ body: body.value }));

  const submit = el('button', {
    className: 'btn btn--primary btn--block',
    type: 'button',
    text: '올리기',
  });
  submit.addEventListener('click', () => openConfirm());

  replace(
    root,
    el('div', { className: 'screen shell stack' }, [
      songHead(draft.song, { size: 300 }),
      body,
      // 라벨은 올리기 버튼 **바로 위**에. 질문 형태로 묻지 않는다 —
      // 질문이면 답해야 할 것 같은 압박이 생긴다. 칩만 조용히 놓는다.
      chipRow('계절', SEASONS, SEASON_LABELS, () => season, (v) => { season = v; setDraft({ season }); }),
      chipRow('시절', ERAS, ERA_LABELS, () => era, (v) => { era = v; setDraft({ era }); }),
      submit,
    ]),
  );

  queueMicrotask(() => body.focus());

  /**
   * 토글 칩 한 줄. 다시 누르면 해제된다 — **안 고르고 올려도 아무 일이 없다.**
   * 라벨이 안 붙는 글이 많은 게 정상이다.
   */
  function chipRow(labelText, values, names, get, set) {
    const buttons = values.map((v) =>
      el('button', {
        className: 'chip',
        type: 'button',
        text: names[v],
        attrs: { 'aria-pressed': String(get() === v) },
      }),
    );
    buttons.forEach((btn, i) => {
      btn.addEventListener('click', () => {
        const v = values[i];
        set(get() === v ? null : v);
        buttons.forEach((b, j) => b.setAttribute('aria-pressed', String(get() === values[j])));
      });
    });
    return el('div', { attrs: { role: 'group', 'aria-label': labelText } }, [
      el('div', { className: 'chips' }, buttons),
    ]);
  }

  /**
   * ④ 공개 확인 시트. **팝업은 한 번뿐이다** — PII 경고를 여기 같이 넣는다.
   *
   * 핵심 문장은 "이름은 남지 않아요". 사람들이 공개를 망설이는 이유가 대개 그거다.
   */
  function openConfirm() {
    const text = body.value.trim();
    if (text.length === 0) {
      body.focus();
      return;
    }

    // 서버와 **같은 함수**로 미리 본다. 판정은 서버가 하고, 여기서는 시트 안에
    // 걸린 부분을 같이 보여주려고만 쓴다. 팝업이 연달아 두 번 뜨면 안 된다.
    const hits = detectPII(text);

    const post = el('button', {
      className: 'btn btn--primary',
      type: 'button',
      text: '올리기',
      attrs: hits.length > 0 ? { disabled: 'disabled' } : {},
    });
    const cancel = el('button', { className: 'btn', type: 'button', text: '고칠게요' });
    const status = el('p', { className: 'tertiary' });

    const node = sheet({
      title: '이 글은 공개돼요',
      onClose: close,
      children: [
        el('p', {
          className: 'sheet__body',
          text: '낯선 사람들의 피드로 흘러가요. 이름은 남지 않아요.',
        }),
        hits.length > 0 ? piiBlock(text, hits) : null,
        status,
        el('div', { className: 'sheet__actions' }, [cancel, post]),
      ].filter(Boolean),
    });

    cancel.addEventListener('click', () => {
      close();
      body.focus();
    });

    post.addEventListener('click', async () => {
      post.setAttribute('disabled', 'disabled');
      status.textContent = '올리는 중이에요…';
      // 키는 **글을 쓰려는 순간** 만든다. 읽기만 하는 사람에게 신원을 발급할 이유가 없다.
      ensureKey();
      try {
        const result = await postMemory({
          ...songPayload(),
          body: text,
          season,
          era,
          isPublic: true,
        });
        close();
        clearDraft();
        done(result);
      } catch (err) {
        post.removeAttribute('disabled');
        status.textContent = err.message;
        status.className = 'tertiary danger';
        // 서버가 잡은 PII 를 같은 시트 안에 덧그린다. 새 팝업을 띄우지 않는다.
        if (err.code === 'pii_detected' && err.spans?.length) {
          post.setAttribute('disabled', 'disabled');
          status.after(piiBlock(text, err.spans));
        }
      }
    });

    document.body.append(node);

    function close() {
      node.remove();
    }
  }

  /**
   * 서버로 보낼 곡.
   *
   * **이미 있는 곡이면 id 하나만 보낸다.** 화면은 `title_key` 같은 값을 갖고 있지 않고
   * (곡 상세 응답에 없다) 가질 이유도 없다. 새 곡일 때만 전부 보낸다.
   */
  function songPayload() {
    const s = draft.song;
    if (s.existingSongId) return { songId: String(s.existingSongId) };
    return {
      song: {
        source: s.source,
        itunesArtistId: s.itunesArtistId ?? undefined,
        itunesTrackId: s.itunesTrackId ?? undefined,
        titleKey: s.titleKey,
        title: s.title,
        artist: s.artist,
        artworkUrl: s.artworkUrl ?? undefined,
        youtubeVideoId: s.youtubeVideoId,
      },
    };
  }

  /**
   * 걸린 부분을 본문 위에 그대로 표시한다. 어디가 문제인지 말로만 하면 못 찾는다.
   * 남이 쓴 글이므로 전부 textContent 로 들어간다.
   */
  function piiBlock(text, spans) {
    const parts = [];
    let cursor = 0;
    for (const s of [...spans].sort((a, b) => a.index - b.index)) {
      if (s.index > cursor) parts.push(document.createTextNode(text.slice(cursor, s.index)));
      parts.push(el('mark', { className: 'pii__mark', text: text.slice(s.index, s.index + s.length) }));
      cursor = s.index + s.length;
    }
    if (cursor < text.length) parts.push(document.createTextNode(text.slice(cursor)));

    const kinds = [...new Set(spans.map((s) => s.label))].join('·');
    return el('div', { className: 'pii' }, [
      el('p', { className: 'sheet__body', text: `${kinds}로 보이는 부분이 있어요. 지우고 올려주세요.` }),
      el('p', { className: 'memory__body' }, parts),
    ]);
  }

  /**
   * 올라간 뒤. **복구 코드는 전용 화면을 만들지 않는다** —
   * 올라간 내 글 옆에 조용히 둔다. 방금 낯선 사람들에게 기억을 내놓은 여운 안에
   * 암호 같은 문자열을 들이밀면 장르가 깨지고 두 번째 글을 안 쓴다.
   *
   * 이 화면은 **글이 저장된 다음에** 뜬다. 여기서 그냥 닫고 나가도 글은 이미 올라가 있다.
   */
  function done(result) {
    const nodes = [
      el('p', { className: 'muted', text: '올라갔어요.' }),
      el('a', {
        className: 'btn btn--primary btn--block',
        href: `#/song/${result.songId}`,
        text: '올라간 글 보기',
      }),
    ];

    // 동시 등록에서 진 경우 — 고른 영상이 말없이 버려졌다는 걸 알린다.
    if (result.videoWasAlreadySet) {
      nodes.push(
        el('p', {
          className: 'muted',
          text: '이 곡은 먼저 온 분이 정해둔 영상이 있어서 그 영상으로 묶였어요. 글은 그대로 올라갔어요.',
        }),
      );
    }

    // **첫 글이 올라간 다음에만** 뜬다. 이 순서가 중요하다 — 여기서 그냥 닫고 나가도
    // 글은 이미 올라가 있다. 복구 코드 화면이 첫 글을 막지 않으므로 이 방식의 가장 큰
    // 위험(첫 글 이탈)이 구조적으로 제거된다.
    if (!hasSeenRecovery()) {
      nodes.push(recoveryBlock());
      markRecoverySeen();
    }

    replace(root, el('div', { className: 'screen shell stack' }, nodes));
  }

  /** 경고가 아니라 안내다. */
  function recoveryBlock() {
    const key = readKey();
    const copy = el('button', { className: 'btn', type: 'button', text: '복사하기' });
    const later = el('button', { className: 'btn', type: 'button', text: '나중에 할게요' });
    const block = el('div', { className: 'recovery' }, [
      el('p', {
        className: 'sheet__body',
        text: '이 글은 이 기기에 저장됐어요. 이 코드를 적어두면 다른 기기에서도 꺼낼 수 있어요.',
      }),
      el('p', { className: 'recovery__code', text: key ?? '' }),
      el('div', { className: 'sheet__actions' }, [later, copy]),
    ]);

    copy.addEventListener('click', async () => {
      try {
        await navigator.clipboard.writeText(key ?? '');
        copy.textContent = '복사했어요';
      } catch {
        // 클립보드가 막힌 브라우저도 있다. 코드는 이미 화면에 떠 있다.
        copy.textContent = '길게 눌러 복사해주세요';
      }
    });
    // 나중에는 ⑦ 내 갈피에서 언제든 다시 볼 수 있다.
    later.addEventListener('click', () => block.remove());

    return block;
  }
}
