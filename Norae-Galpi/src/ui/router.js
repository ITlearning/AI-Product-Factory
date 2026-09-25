/**
 * 해시 라우터. 화면 일곱을 잇는 최소한의 것.
 *
 * 해시를 쓰는 이유 — Vercel 리라이트가 이미 모든 경로를 index.html 로 보내지만,
 * 해시면 서버 설정과 무관하게 새로고침·뒤로가기가 항상 맞는다.
 *
 * 경로
 *   #/            ⑤ 홈 피드
 *   #/start       ① 곡 검색 (온보딩)
 *   #/video       ② 영상 확정
 *   #/write       ③④ 기억 적기
 *   #/song/:id    ⑥ 곡 상세
 *   #/mine        ⑦ 내 갈피
 */

/**
 * 현재 경로를 조각으로.
 *
 * @returns {{name: string, param: string|null, query: URLSearchParams}}
 */
export function currentRoute() {
  const raw = location.hash.replace(/^#/, '') || '/';
  const [path, search = ''] = raw.split('?');
  const parts = path.split('/').filter(Boolean);
  return {
    name: parts[0] ?? '',
    param: parts[1] ?? null,
    query: new URLSearchParams(search),
  };
}

/**
 * @param {string} path - 예: `/song/12`
 * @param {Record<string, string>} [query]
 */
export function go(path, query) {
  const q = query && Object.keys(query).length ? `?${new URLSearchParams(query)}` : '';
  location.hash = `#${path}${q}`;
}

/**
 * @param {() => void} onChange
 * @returns {() => void} 해제
 */
export function onRouteChange(onChange) {
  window.addEventListener('hashchange', onChange);
  return () => window.removeEventListener('hashchange', onChange);
}
