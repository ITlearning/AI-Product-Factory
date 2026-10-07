// 앱의 Color-Moments/PRIVACY.md → privacy.html. 원본은 md 하나뿐이고, 이 html 은 그 사본이다(손으로 고치지 말 것).
// 그 md 에 실제로 쓰는 문법만 안다: # ## ### 제목, 문단, `- ` 목록, | 표 |, **굵게**, [글](주소), `코드`, 맨 주소.
// 이 밖의 문법(번호 목록, 인용, 기울임, 그림 …)은 글자 그대로 나온다 — md 에 새로 쓰면 여기부터 늘릴 것.
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

export const SOURCE = new URL('../../Color-Moments/PRIVACY.md', import.meta.url);
export const TARGET = new URL('../privacy.html', import.meta.url);
const REPO_BLOB = 'https://github.com/ITlearning/AI-Product-Factory/blob/main/Color-Moments/';

export const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');

// GitHub 에서 읽던 md 라, 자기 자신을 가리키는 주소는 이 페이지로, 상대 링크는 저장소 주소로 바꾼다.
// 허용 안 된 스킴(javascript: 등)은 null → 링크 없이 글자만.
export function resolveHref(href) {
  if (/^https:\/\/(github\.com\/ITlearning\/AI-Product-Factory\/(blob|tree)\/[^/]+|raw\.githubusercontent\.com\/ITlearning\/AI-Product-Factory\/[^/]+)\/Color-Moments\/PRIVACY\.md(#.*)?$/i.test(href)) {
    return '/privacy' + (href.match(/#.*$/)?.[0] ?? '');
  }
  if (/^(https?:|mailto:)/i.test(href)) return href;
  if (href.startsWith('#')) return href;
  if (/^[a-z][a-z0-9+.-]*:/i.test(href) || href.startsWith('//') || href.startsWith('/')) return null;
  const path = href.replace(/^\.\//, '');
  if (/^PRIVACY\.md(#.*)?$/i.test(path)) return '/privacy' + (path.match(/#.*$/)?.[0] ?? '');
  return REPO_BLOB + path;
}

const link = (href, innerHtml) => {
  const to = resolveHref(href);
  return to === null ? innerHtml : `<a href="${esc(to)}">${innerHtml}</a>`;
};

// 맨 주소 끝의 문장부호(마침표·괄호 등)는 주소에 넣지 않는다.
const INLINE = /`([^`]+)`|\[([^\]]+)\]\(([^)\s]+)\)|\*\*(.+?)\*\*|(https?:\/\/[^\s<>()[\]]*[^\s<>()[\].,;:!?'"])/;

export function inline(src, { autolink = true } = {}) {
  let out = '';
  let s = src;
  while (s) {
    const m = INLINE.exec(s);
    if (!m) { out += esc(s); break; }
    out += esc(s.slice(0, m.index));
    if (m[1] !== undefined) out += `<code>${esc(m[1])}</code>`;
    else if (m[2] !== undefined) out += link(m[3], inline(m[2], { autolink: false }));
    else if (m[4] !== undefined) out += `<strong>${inline(m[4], { autolink })}</strong>`;
    else out += autolink ? link(m[5], esc(m[5])) : esc(m[5]);
    s = s.slice(m.index + m[0].length);
  }
  return out;
}

const cells = (line) => line.trim().replace(/^\|/, '').replace(/\|$/, '').split('|').map((c) => c.trim());
const isTableSep = (line) => /^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$/.test(line);

// 본문만 만든다. 맨 처음 # 제목은 페이지 머리가 대신하므로 { title } 로 돌려준다.
export function mdToHtml(md) {
  const lines = md.replace(/\r\n?/g, '\n').split('\n');
  const out = [];
  let title = null;
  let i = 0;
  const tableAt = (k) => /^\s*\|/.test(lines[k]) && isTableSep(lines[k + 1] ?? '');
  while (i < lines.length) {
    const line = lines[i];
    if (!line.trim()) { i++; continue; }
    const h = /^(#{1,3}) +(.*?)\s*#*\s*$/.exec(line);
    if (h) {
      // 페이지의 h1 은 머리가 쓰므로 md 의 # 는 (맨 처음 것 말고는) h2 로 내린다.
      const n = Math.max(2, h[1].length);
      if (h[1].length === 1 && title === null && out.length === 0) title = h[2];
      else out.push(`<h${n}>${inline(h[2])}</h${n}>`);
      i++;
      continue;
    }
    if (tableAt(i)) {
      const head = cells(line);
      i += 2;
      const rows = [];
      while (i < lines.length && /^\s*\|/.test(lines[i])) rows.push(cells(lines[i++]));
      out.push(
        '<div class="table-wrap"><table>',
        `<thead><tr>${head.map((c) => `<th scope="col">${inline(c)}</th>`).join('')}</tr></thead>`,
        `<tbody>${rows.map((r) => `<tr>${head.map((_, k) => `<td>${inline(r[k] ?? '')}</td>`).join('')}</tr>`).join('\n')}</tbody>`,
        '</table></div>',
      );
      continue;
    }
    if (/^- /.test(line)) {
      const items = [];
      while (i < lines.length && /^- /.test(lines[i])) {
        let text = lines[i++].slice(2);
        while (i < lines.length && /^ {2,}\S/.test(lines[i])) text += '\n' + lines[i++].trim();
        items.push(`<li>${inline(text)}</li>`);
      }
      out.push(`<ul>\n${items.join('\n')}\n</ul>`);
      continue;
    }
    const para = [];
    while (i < lines.length && lines[i].trim() && !/^#{1,3} /.test(lines[i]) && !/^- /.test(lines[i]) && !tableAt(i)) para.push(lines[i++].trim());
    out.push(`<p>${inline(para.join('\n'))}</p>`);
  }
  return { title, body: out.join('\n') };
}

export function renderPage(md) {
  const { body } = mdToHtml(md);
  return `<!doctype html>
<!-- npm run build:privacy 로 Color-Moments/PRIVACY.md 에서 만든 파일 — 손으로 고치지 말 것 -->
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="robots" content="noindex, nofollow">
<meta name="theme-color" content="#06070A">
<meta name="color-scheme" content="dark">
<meta name="format-detection" content="telephone=no">
<title>몽돌 · 개인정보 처리방침</title>
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Cellipse cx='16' cy='17' rx='12' ry='11' fill='%23F4A58A'/%3E%3Cellipse cx='13' cy='13' rx='5' ry='3.5' fill='%23fff' opacity='.5'/%3E%3C/svg%3E">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Gowun+Dodum&family=Nanum+Myeongjo:wght@800&display=swap">
<link rel="stylesheet" href="./styles.css">
</head>
<body>
<main class="page">
  <header class="doc-head">
    <p class="wordmark">몽돌</p>
    <h1 class="doc-title">개인정보 처리방침</h1>
  </header>
  <article class="doc">
${body}
  </article>
  <footer class="doc-foot"><a href="/feedback">건의하기</a></footer>
</main>
</body>
</html>
`;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  writeFileSync(TARGET, renderPage(readFileSync(SOURCE, 'utf8')));
  console.log(`privacy.html ← ${fileURLToPath(SOURCE)}`);
}
