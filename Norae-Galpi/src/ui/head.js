/**
 * `<head>` 손보기.
 *
 * ⑥ 곡 상세는 v1에서 **검색엔진에 열지 않는다.** 서버가 `X-Robots-Tag` 를 보내지만
 * 화면이 해시 라우팅이라 크롤러가 보는 문서는 index.html 하나다. 그래서 여기서도 건다.
 */

/**
 * @param {boolean} on
 */
export function setNoindex(on) {
  let tag = document.querySelector('meta[name="robots"]');
  if (!tag) {
    tag = document.createElement('meta');
    tag.setAttribute('name', 'robots');
    document.head.append(tag);
  }
  tag.setAttribute('content', on ? 'noindex, nofollow' : 'index, follow');
}

/**
 * 화면마다 문서 제목을 바꾼다 — 탭이 여러 개 열린 사람이 어디가 어딘지 알 수 있게.
 *
 * @param {string|null} suffix
 */
export function setTitle(suffix) {
  document.title = suffix ? `${suffix} · 노래갈피` : '노래갈피';
}
