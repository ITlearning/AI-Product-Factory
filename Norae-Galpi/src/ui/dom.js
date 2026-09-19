/**
 * 아주 작은 DOM 헬퍼. 프레임워크를 쓰지 않으므로 여기서 지켜야 하는 게 하나 있다 —
 * **남이 쓴 글을 innerHTML 로 넣지 않는다.**
 *
 * 기억 본문·곡 제목·유튜브 영상 제목은 전부 남이 만든 문자열이다.
 * 그걸 문자열 템플릿으로 조립해 innerHTML 에 꽂는 순간 이 제품은 XSS 게시판이 된다.
 * 그래서 텍스트는 항상 `textContent` 로만 들어간다.
 */

/**
 * 엘리먼트를 만든다.
 *
 * @param {string} tag
 * @param {object} [props] - className·textContent·href 등. `dataset`·`attrs` 는 따로 푼다
 * @param {(Node|string|null|false|undefined)[]} [children]
 * @returns {HTMLElement}
 */
export function el(tag, props = {}, children = []) {
  const node = document.createElement(tag);

  for (const [k, v] of Object.entries(props)) {
    if (v == null || v === false) continue;
    if (k === 'dataset') {
      for (const [dk, dv] of Object.entries(v)) node.dataset[dk] = String(dv);
    } else if (k === 'attrs') {
      for (const [ak, av] of Object.entries(v)) {
        if (av != null && av !== false) node.setAttribute(ak, String(av));
      }
    } else if (k === 'on') {
      for (const [ev, fn] of Object.entries(v)) node.addEventListener(ev, fn);
    } else if (k === 'text') {
      // 남이 쓴 글은 여기로만 들어간다.
      node.textContent = String(v);
    } else {
      node[k] = v;
    }
  }

  for (const child of children.flat()) {
    if (child == null || child === false) continue;
    node.append(typeof child === 'string' ? document.createTextNode(child) : child);
  }
  return node;
}

/**
 * 자식을 통째로 갈아끼운다.
 *
 * @param {HTMLElement} parent
 * @param {...(Node|null|false|undefined)} children
 */
export function replace(parent, ...children) {
  parent.replaceChildren(...children.flat().filter(Boolean));
}

/**
 * iTunes 아트워크는 100×100으로 온다. 레티나에서 그대로 쓰면 뭉개진다.
 * URL 끝의 치수만 바꾸면 더 큰 이미지가 오는 건 iTunes의 오래된 동작이고,
 * **실패해도 원본 주소로 되돌아가게** 만들어 둔다.
 *
 * @param {string|null} url
 * @param {number} size
 * @returns {string|null}
 */
export function artworkAt(url, size = 300) {
  if (!url) return null;
  return url.replace(/\/\d+x\d+bb\.(jpg|png)$/, `/${size}x${size}bb.$1`);
}

/**
 * 앨범아트 자리. **주소가 없으면 `<img>` 를 만들지 않는다.**
 *
 * `src=""` 인 img 는 브라우저가 깨진 이미지 아이콘을 그린다. 이 제품에서 앨범아트는
 * 화면에서 유일하게 채도를 가진 것이라, 그 자리에 깨진 아이콘이 뜨면 카드 전체가 망가져 보인다.
 * iTunes 에 없는 곡(`source='youtube'`)은 아직 아트워크가 없을 수 있어 드물지 않은 경우다.
 *
 * @param {string|null} url
 * @param {string} className
 * @param {number} [size]
 * @returns {HTMLElement}
 */
export function artwork(url, className, size = 300) {
  const src = artworkAt(url, size);
  if (!src) return el('div', { className, attrs: { 'aria-hidden': 'true' } });

  const img = el('img', {
    className,
    src,
    alt: '',
    loading: 'lazy',
    attrs: { decoding: 'async' },
  });
  // 주소는 있는데 못 불러오는 경우(지워진 아트워크·차단). 같은 이유로 빈 자리로 바꾼다.
  img.addEventListener('error', () => {
    img.replaceWith(el('div', { className, attrs: { 'aria-hidden': 'true' } }));
  });
  return img;
}

const SVG_NS = 'http://www.w3.org/2000/svg';

/**
 * 아이콘. `el` 은 `createElement` 라 SVG 를 만들지 못한다 — 네임스페이스가 필요하다.
 *
 * 색은 `currentColor` 로 받는다. 탭바가 눌린 탭만 밝히는 일이 CSS 한 줄로 끝나고,
 * 아이콘마다 색 토큰을 박아둘 필요가 없다.
 *
 * `d` 는 이 파일이 아는 상수만 들어온다. 남이 쓴 글은 여기로 오지 않는다.
 *
 * @param {string|string[]} d - path 의 `d` 속성
 * @param {{size?: number}} [opts]
 * @returns {SVGElement}
 */
export function icon(d, opts = {}) {
  const { size = 24 } = opts;
  const svg = document.createElementNS(SVG_NS, 'svg');
  svg.setAttribute('viewBox', '0 0 24 24');
  svg.setAttribute('width', String(size));
  svg.setAttribute('height', String(size));
  svg.setAttribute('fill', 'none');
  // 옆에 글자 레이블이 항상 같이 있다. 스크린리더에 같은 말을 두 번 읽힐 이유가 없다.
  svg.setAttribute('aria-hidden', 'true');

  for (const spec of [].concat(d)) {
    const path = document.createElementNS(SVG_NS, 'path');
    path.setAttribute('d', spec);
    path.setAttribute('stroke', 'currentColor');
    path.setAttribute('stroke-linecap', 'round');
    path.setAttribute('stroke-linejoin', 'round');
    svg.append(path);
  }
  return svg;
}
