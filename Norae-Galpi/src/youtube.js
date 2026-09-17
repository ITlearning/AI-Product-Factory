/**
 * ② 영상 확정 — 유튜브 영상 후보 찾기.
 *
 * ## 키가 없어도 화면이 돈다 (엔지니어링 결정 2)
 * `YOUTUBE_API_KEY`가 없으면 후보 목록 자리에 "유튜브 링크를 직접 넣어주세요"만 뜬다.
 * 그래서 **구글 클라우드 행정이 출시를 막지 않고**, 키를 넣는 순간 자동 검색이 켜진다.
 * 쿼터 소진도 `403 quotaExceeded`도 전부 같은 폴백을 탄다.
 *
 * ## 쿼터 (2026-06-01 모델 개정)
 * `search.list`가 전용 버킷으로 분리됐다. **하루 100 calls가 경성 상한**이고 다른 호출을 아껴도
 * 늘릴 수 없다. 그래서 곡당 1회만 검색하고 DB에 저장하는 설계가 정확하다 — 신규 곡 하루 100개까지 감당한다.
 *
 * **90일 연속 미사용 시 접근이 차단될 수 있어**(Developer Policies III.D.4) 직접 링크 폴백은 항상 열어둔다.
 *
 * ## 약관
 * 표준 IFrame 임베드만 쓴다. 자체 플레이어를 만들지 않고, 소리만 분리하지 않고,
 * 플레이어 위에 아무것도 덮지 않는다. 제재 사례(Musi·Invidious·Vanced)는 전부
 * 광고 우회·비공식 플레이어였다.
 */

import { spendYoutubeSearch } from './ratelimit.js';

const SEARCH_URL = 'https://www.googleapis.com/youtube/v3/search';
const OEMBED_URL = 'https://www.youtube.com/oembed';

/** 후보로 보여줄 영상 수. */
export const VIDEO_CANDIDATE_COUNT = 3;

const VIDEO_ID_RE = /^[A-Za-z0-9_-]{11}$/;

/**
 * 사용자가 붙여넣은 것에서 영상 ID를 뽑는다. **직접 링크 폴백의 입구**다.
 *
 * 모바일에서 링크 복사는 앱 왕복 여섯 단계라 이 경로가 거칠면 첫 곡 등록이 통째로 막힌다.
 * 그래서 받아들일 수 있는 모양을 넓게 잡는다.
 *
 * @param {string} input - URL 또는 ID
 * @returns {string|null} 11자 영상 ID, 못 뽑으면 null
 */
export function parseVideoId(input) {
  if (typeof input !== 'string') return null;
  const s = input.trim();
  if (s.length === 0) return null;

  // 이미 ID만 온 경우
  if (VIDEO_ID_RE.test(s)) return s;

  // URL 로 온 경우. youtu.be/ID · /watch?v=ID · /embed/ID · /shorts/ID · /live/ID
  let url;
  try {
    url = new URL(s.startsWith('http') ? s : `https://${s}`);
  } catch {
    return null;
  }
  const host = url.hostname.replace(/^www\.|^m\./, '');
  if (!/^(youtube\.com|youtube-nocookie\.com|youtu\.be)$/.test(host)) return null;

  if (host === 'youtu.be') {
    const id = url.pathname.slice(1).split('/')[0];
    return VIDEO_ID_RE.test(id) ? id : null;
  }
  const v = url.searchParams.get('v');
  if (v && VIDEO_ID_RE.test(v)) return v;

  const m = url.pathname.match(/^\/(?:embed|shorts|live|v)\/([A-Za-z0-9_-]{11})/);
  return m ? m[1] : null;
}

/**
 * 영상 후보를 찾는다.
 *
 * **실패를 예외로 던지지 않는다.** 키가 없든 쿼터가 끝났든 구글이 죽었든,
 * ② 화면이 해야 하는 일은 같다 — 직접 링크 입력만 남기는 것. 그래서 이유를 담아 돌려준다.
 *
 * @param {string} query - "곡명 가수명"
 * @param {{apiKey?: string, fetchImpl?: typeof fetch, now?: Date}} [opts]
 * @returns {Promise<{available: boolean, reason?: 'no_key'|'quota'|'error',
 *                    videos: {videoId: string, title: string, channel: string, thumbnail: string|null}[]}>}
 */
export async function findVideos(query, opts = {}) {
  const { fetchImpl = fetch, now = new Date() } = opts;
  const apiKey = opts.apiKey ?? process.env.YOUTUBE_API_KEY;

  // 키가 없다 — 출시를 막지 않는 그 경로.
  if (!apiKey) return { available: false, reason: 'no_key', videos: [] };

  // 우리가 세는 쿼터. 구글이 403을 주기 전에 먼저 멈춘다.
  const quota = await spendYoutubeSearch(now);
  if (!quota.ok) return { available: false, reason: 'quota', videos: [] };

  const url =
    `${SEARCH_URL}?part=snippet&type=video&videoEmbeddable=true` +
    `&maxResults=${VIDEO_CANDIDATE_COUNT}&q=${encodeURIComponent(query)}&key=${apiKey}`;

  let body;
  try {
    const res = await fetchImpl(url);
    if (res.status === 403) {
      // quotaExceeded 도 같은 폴백을 탄다. 다른 403(키 제한 등)도 화면이 할 일은 같다.
      return { available: false, reason: 'quota', videos: [] };
    }
    if (!res.ok) return { available: false, reason: 'error', videos: [] };
    body = await res.json();
  } catch {
    return { available: false, reason: 'error', videos: [] };
  }

  const videos = (body.items ?? [])
    .map((it) => ({
      videoId: it?.id?.videoId,
      title: it?.snippet?.title ?? '',
      channel: it?.snippet?.channelTitle ?? '',
      thumbnail: it?.snippet?.thumbnails?.medium?.url ?? it?.snippet?.thumbnails?.default?.url ?? null,
    }))
    .filter((v) => VIDEO_ID_RE.test(v.videoId ?? ''));

  return { available: true, videos };
}

/**
 * 영상이 살아 있는지 + 제목이 무엇인지. oEmbed는 살아있으면 200, 삭제·비공개·임베드 금지면 400이다(실측).
 *
 * **⑥ 곡 상세 진입 때마다 부르지 않는다**(엔지니어링 결정 8). 가장 자주 열리는 화면에 외부 왕복이
 * 매번 붙는 값이 크고, 죽은 영상은 iframe이 알아서 에러를 보여주며 "영상이 곡과 달라요" 신고 경로가 이미 있다.
 * 직접 링크로 곡을 **등록할 때** 한 번 쓴다 — 그때는 사용자가 뭘 붙였는지 확인해줄 값이 있다.
 *
 * @param {string} videoId
 * @param {{fetchImpl?: typeof fetch}} [opts]
 * @returns {Promise<{alive: boolean, title: string|null, channel: string|null, thumbnail: string|null}>}
 */
export async function probeVideo(videoId, opts = {}) {
  const { fetchImpl = fetch } = opts;
  if (!VIDEO_ID_RE.test(videoId ?? '')) {
    return { alive: false, title: null, channel: null, thumbnail: null };
  }
  const url =
    `${OEMBED_URL}?url=${encodeURIComponent(`https://www.youtube.com/watch?v=${videoId}`)}&format=json`;
  try {
    const res = await fetchImpl(url);
    if (!res.ok) return { alive: false, title: null, channel: null, thumbnail: null };
    const body = await res.json();
    return {
      alive: true,
      title: body.title ?? null,
      channel: body.author_name ?? null,
      thumbnail: body.thumbnail_url ?? null,
    };
  } catch {
    // 네트워크 실패를 "죽은 영상"으로 단정하지 않는다. 확인 못 했을 뿐이다.
    return { alive: true, title: null, channel: null, thumbnail: null };
  }
}

/**
 * `source='youtube'` 곡의 아트워크. iTunes 아트워크가 없으니 유튜브 썸네일을 쓴다.
 *
 * @param {string} videoId
 * @returns {string}
 */
export function thumbnailUrl(videoId) {
  return `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`;
}
