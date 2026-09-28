/**
 * iTunes Search API — 곡 검색 · 표시명 · 곡 키.
 *
 * 무인증이고 CORS가 `*`다. 곡당 호출은 **검색 1회 + lookup 1회**로 끝난다.
 *
 * ## 왜 두 번 부르는가 (실측)
 * `country=us`로 검색하면 한국어 질의 정확도가 최상인데 **표기가 영문으로 온다.**
 * 「밤편지」가 `Through the Night`, 「노래방에서」가 `Karaoke`, 「희망고문」이 `BLUES`로 온다.
 * 문자열이 하나도 안 겹쳐서, us 제목으로 후보를 보여주면 사용자가 자기 곡을 못 알아본다
 * (드라이런에서 실제로 6곡을 놓쳤다). 그래서 `lookup?country=kr`로 표시명을 한 번 더 가져온다.
 *
 * ## 함정
 * - `entity=song` + `country=kr` 조합은 **항상 resultCount 0**을 반환한다. `media=music`을 쓸 것
 * - `country=kr` 단독 검색은 표기는 한글로 오지만 previewUrl이 없고 검색이 불안정하다
 * - `lookup`은 id를 콤마로 묶어 배치 조회가 된다 — 후보 6개가 요청 1회다
 */

const SEARCH_URL = 'https://itunes.apple.com/search';
const LOOKUP_URL = 'https://itunes.apple.com/lookup';

/** 검색에서 가져올 후보 수. 이 중에서 재정렬해 3개를 보여준다. */
export const SEARCH_LIMIT = 6;

/** 화면에 내보내는 후보 수. **자동 선택은 하지 않는다.** */
export const CANDIDATE_COUNT = 3;

/** `title_key` 정규화 규칙의 버전. 규칙을 바꾸면 올리고 백필 대상을 이걸로 식별한다. */
export const TITLE_KEY_REV = 1;

/**
 * 곡 키 정규화. **`country=us` 응답의 `trackName` 기준으로 만든다** —
 * `kr` 응답은 누락되는 곡이 있어 키로 쓸 수 없다.
 *
 * 규칙 2(괄호 안 제거)는 같은 아티스트의 Live·Acoustic·Remix를 원곡과 한 카드로 합친다.
 * **이건 의도다.** "밤편지 라이브"를 들으며 생긴 기억도 "밤편지"의 기억이고,
 * 버전별로 카드가 갈리면 기억이 흩어진다. 반대로 남이 부른 커버는 `artistId`가 달라
 * 자동으로 분리된다. 두 동작이 한 규칙에서 나온다.
 *
 * @param {string} trackName - us 응답의 trackName
 * @returns {string}
 */
export function titleKey(trackName) {
  if (typeof trackName !== 'string') throw new TypeError('trackName must be a string');

  // 1) 유니코드 NFC. `L'Amour`(일반 아포스트로피)와 `L’Amour`(타이포그래픽)가 여기서 갈린다 —
  //    NFC는 둘을 합치지 않으므로 기호 제거(5)까지 가야 같은 키가 된다.
  const nfc = trackName.normalize('NFC');

  // 2) 괄호·대괄호로 묶인 부가 표기 제거. 중첩이 있을 수 있어 더 줄어들지 않을 때까지 돈다.
  let s = nfc;
  for (let prev = null; prev !== s; ) {
    prev = s;
    s = s.replace(/\([^()]*\)|\[[^[\]]*\]|（[^（）]*）/g, ' ');
  }

  // 3) 하이픈 뒤 꼬리표 제거 — `- Remastered 2011`, `- Radio Edit`.
  //    `- Single`·`- EP`는 trackName이 아니라 collectionName에 붙으므로 여기 해당하지 않는다.
  //    공백으로 둘러싸인 하이픈만 본다. 제목 안의 붙임표를 지우지 않기 위해서다.
  s = s.replace(/\s[-–—]\s.*$/u, '');

  // 4) 소문자화. 한글에는 대소문자가 없어 무해하다.
  s = s.toLowerCase();

  // 5) 공백·문장부호·기호 전부 제거.
  s = s.replace(/[\p{White_Space}\p{P}\p{S}]/gu, '');

  // 6) 남은 문자열이 비면 원본을 NFC만 적용해 쓴다.
  //    (제목 전체가 괄호인 곡 — 키가 빈 문자열이면 UNIQUE가 전부 충돌한다)
  return s.length > 0 ? s : nfc;
}

/** 괄호·대괄호 안에서만 찾는 반주 표시. */
const MR_TOKENS = /\b(mr|inst|instrumental)\b|남자키|여자키|반주/i;

/**
 * 반주(MR·Inst) 트랙인지. **괄호·대괄호 안으로 한정해서** 본다.
 *
 * 제목 전체를 검사하면 「노래방에서」가 `노래방` 때문에 오탐된다 —
 * 드라이런에서 실제로 터진 회귀 케이스다.
 *
 * @param {string} trackName
 * @returns {boolean}
 */
export function looksLikeInstrumental(trackName) {
  if (typeof trackName !== 'string') return false;
  const groups = trackName.normalize('NFC').match(/\([^()]*\)|\[[^[\]]*\]|（[^（）]*）/g) ?? [];
  return groups.some((g) => MR_TOKENS.test(g));
}

/**
 * 대조용 정규화 — 사용자 입력과 한글 표시명을 같은 바닥에 놓는다.
 * `titleKey`와 달리 **괄호 안을 지우지 않는다.** 사용자가 "밤편지 라이브"라고 칠 수도 있다.
 *
 * @param {string} s
 * @returns {string}
 */
function forMatching(s) {
  return String(s ?? '')
    .normalize('NFC')
    .toLowerCase()
    .replace(/[\p{White_Space}\p{P}\p{S}]/gu, '');
}

/**
 * 대조용 **알맹이** 제목 — 괄호 안과 하이픈 꼬리표를 걷어낸 것.
 *
 * 사용자는 `(feat. YUMDDA, GIRIBOY & Zion.T)` 를 쳐서 찾지 않는다. 전체 제목으로만 대조하면
 * 「CREDIT 릴보이」에서 릴보이의 원곡이 아니라 제목이 딱 `Credit` 인 남의 곡이 1순위가 된다
 * (드라이런 픽스처에서 실제로 그랬다).
 *
 * `titleKey`와 규칙은 같지만 **빈 문자열 폴백이 없다** — 대조에서는 빈 값이 그냥 '못 맞춤'이다.
 *
 * @param {string} s
 * @returns {string}
 */
function coreForMatching(s) {
  let t = String(s ?? '').normalize('NFC');
  for (let prev = null; prev !== t; ) {
    prev = t;
    t = t.replace(/\([^()]*\)|\[[^[\]]*\]|（[^（）]*）/g, ' ');
  }
  t = t.replace(/\s[-–—]\s.*$/u, '');
  return forMatching(t);
}

/**
 * 후보 재정렬. **한글 기준으로** 사용자 입력과 대조한다.
 *
 * 아티스트는 필터가 아니라 **순위 가중치**다. `프로미스나인` vs `fromis_9`는 kr lookup에서도
 * 안 맞기 때문에, 제목이 맞으면 후보에 넣고 아티스트가 맞으면 위로 올린다.
 * 둘 다 요구하면 영문 활동명 그룹이 전부 떨어진다.
 *
 * @param {string} query - 사용자가 친 말
 * @param {{trackId: number, trackName: string, artistName: string,
 *          krTrackName?: string, krArtistName?: string}[]} candidates
 * @returns {object[]} 점수순 내림차순. 원본 배열을 바꾸지 않는다.
 */
export function rankCandidates(query, candidates) {
  const q = forMatching(query);

  const scored = candidates.map((c, i) => {
    // 표기는 kr 우선. kr 조회가 비면 us 값을 그대로 쓴다.
    const title = c.krTrackName ?? c.trackName ?? '';
    const artist = c.krArtistName ?? c.artistName ?? '';
    const t = forMatching(title);
    const core = coreForMatching(title);
    const a = forMatching(artist);

    // 제목 점수는 전체 제목과 알맹이 제목 중 더 잘 맞는 쪽을 쓴다.
    // 전체가 맞으면 알맹이보다 조금 높다 — 정확한 쪽이 낫기 때문이다.
    let score = 0;
    if (t.length > 0 && q.includes(t)) score += 100;             // 질의가 제목을 통째로 품는다
    else if (core.length > 0 && q.includes(core)) score += 95;   // 괄호를 걷으면 품는다
    else if (t.length > 0 && t.includes(q)) score += 60;         // 질의가 제목의 일부다
    else if (core.length > 0 && core.includes(q)) score += 55;
    else score += Math.max(overlapRatio(q, t), overlapRatio(q, core)) * 40;

    // 아티스트는 가중치일 뿐. 안 맞아도 후보에서 떨어뜨리지 않는다.
    if (a.length > 0 && (q.includes(a) || a.includes(q))) score += 30;
    // us 표기로도 한 번 본다 — 사용자가 `fromis_9`라고 칠 수도 있다.
    else if (forMatching(c.artistName) && q.includes(forMatching(c.artistName))) score += 30;

    // 반주는 맨 뒤로. 버리지는 않는다 — 진짜로 MR을 찾는 사람도 있다.
    if (looksLikeInstrumental(c.trackName) || looksLikeInstrumental(title)) score -= 1000;

    return { c, score, i };
  });

  // 점수 같으면 iTunes가 준 순서를 지킨다(안정 정렬).
  scored.sort((x, y) => y.score - x.score || x.i - y.i);
  return scored.map((s) => s.c);
}

/**
 * 두 문자열의 문자 겹침 비율. 한글은 형태소 분석 없이도 이 정도면 원곡을 위로 올린다.
 *
 * @param {string} a
 * @param {string} b
 * @returns {number} 0~1
 */
function overlapRatio(a, b) {
  if (a.length === 0 || b.length === 0) return 0;
  const bag = new Map();
  for (const ch of b) bag.set(ch, (bag.get(ch) ?? 0) + 1);
  let hit = 0;
  for (const ch of a) {
    const n = bag.get(ch) ?? 0;
    if (n > 0) {
      hit += 1;
      bag.set(ch, n - 1);
    }
  }
  return hit / Math.max(a.length, b.length);
}

/**
 * 곡 검색. `country=us` · `media=music`.
 *
 * @param {string} term
 * @param {{limit?: number, fetchImpl?: typeof fetch}} [opts]
 * @returns {Promise<object[]>} us 응답의 track 배열
 */
export async function searchSongs(term, opts = {}) {
  const { limit = SEARCH_LIMIT, fetchImpl = fetch } = opts;
  const url = `${SEARCH_URL}?term=${encodeURIComponent(term)}&media=music&country=us&limit=${limit}`;
  const res = await fetchImpl(url);
  if (!res.ok) throw new Error(`iTunes search ${res.status}`);
  const body = await res.json();
  return (body.results ?? []).filter((r) => r.wrapperType === 'track' || r.kind === 'song');
}

/**
 * 한글 표기 배치 조회. id를 콤마로 묶어 **요청 1회**로 끝난다.
 *
 * @param {(number|string)[]} trackIds
 * @param {{fetchImpl?: typeof fetch}} [opts]
 * @returns {Promise<Map<string, {trackName: string, artistName: string, artworkUrl100?: string}>>}
 *   trackId(문자열) → kr 표기. 조회가 비면 그 id는 없다 — 호출 측이 us 값으로 폴백한다.
 */
export async function lookupKr(trackIds, opts = {}) {
  const { fetchImpl = fetch } = opts;
  const ids = [...new Set(trackIds.map(String))].filter(Boolean);
  if (ids.length === 0) return new Map();

  const url = `${LOOKUP_URL}?id=${ids.join(',')}&country=kr&entity=song`;
  const res = await fetchImpl(url);
  if (!res.ok) throw new Error(`iTunes lookup ${res.status}`);
  const body = await res.json();

  const out = new Map();
  for (const r of body.results ?? []) {
    if (r.wrapperType !== 'track' && r.kind !== 'song') continue;
    out.set(String(r.trackId), {
      trackName: r.trackName,
      artistName: r.artistName,
      artworkUrl100: r.artworkUrl100,
    });
  }
  return out;
}

/**
 * ① 곡 검색 화면이 쓰는 전체 파이프라인.
 *
 *   search(us, limit 6) → lookup(kr, 배치 1회) → 한글 기준 재정렬 → MR 하향 → 후보 3개
 *
 * **자동 선택이 없다.** 첫 항목이 미리 선택된 상태로 그려지면 안 되고,
 * "찾는 곡이 없어요"를 결과가 있을 때도 항상 보여줘야 한다 —
 * iTunes에 없는 곡을 검색해도 빈손으로 돌아오지 않고 **그럴듯한 오답**이 오기 때문이다
 * (「그래 우리 함께」 → 방탄소년단 봄날). 사용자가 확인 없이 넘어가면 기억이 엉뚱한 곡에 붙고,
 * 그 곡의 첫 사람이면 유튜브 영상까지 그쪽으로 고정된다.
 *
 * @param {string} term
 * @param {{limit?: number, count?: number, fetchImpl?: typeof fetch}} [opts]
 * @returns {Promise<{trackId: number, artistId: number, titleKey: string,
 *                    title: string, artist: string, artworkUrl: string|null,
 *                    usTrackName: string}[]>}
 */
export async function findCandidates(term, opts = {}) {
  const { count = CANDIDATE_COUNT, fetchImpl = fetch } = opts;
  const results = await searchSongs(term, { limit: opts.limit, fetchImpl });
  if (results.length === 0) return [];

  const kr = await lookupKr(results.map((r) => r.trackId), { fetchImpl });

  const merged = results.map((r) => {
    const k = kr.get(String(r.trackId));
    return { ...r, krTrackName: k?.trackName, krArtistName: k?.artistName, krArtwork: k?.artworkUrl100 };
  });

  return rankCandidates(term, merged)
    .slice(0, count)
    .map((r) => ({
      trackId: r.trackId,
      artistId: r.artistId,
      // 키는 반드시 us 이름으로 만든다. kr은 누락되는 곡이 있다.
      titleKey: titleKey(r.trackName),
      title: r.krTrackName ?? r.trackName,
      artist: r.krArtistName ?? r.artistName,
      artworkUrl: r.krArtwork ?? r.artworkUrl100 ?? null,
      usTrackName: r.trackName,
    }));
}
