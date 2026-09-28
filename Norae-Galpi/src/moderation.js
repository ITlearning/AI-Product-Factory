/**
 * PII 정규식 검출 — v1 모더레이션의 유일한 자동 층.
 *
 * 설계(`docs/designs/norae-galpi.md` → 모더레이션)가 정한 범위는 딱 세 가지다.
 * 전화번호 · 계좌번호꼴 숫자열 · 이메일. 걸리면 저장하지 않고 즉시 돌려주며
 * **어느 부분인지 표시**한다(④ 공개 확인 시트 안에서 한 번만).
 *
 * 여기 없는 것 — 실명+소속 조합, 맥락상 저격, 유해물. 전부 v2의 LLM 의미 판정 몫이고
 * v1에서는 신고로만 잡힌다. 정규식으로 잡는 척하지 않는다.
 *
 * ## 오탐을 피하는 쪽으로 기울여 놓았다
 * "PII 정규식에 걸렸을 때의 화면 톤"이 미결 질문으로 남아 있을 만큼,
 * 여기서 억울하게 막히면 그 사람은 안 돌아온다. 그래서 계좌번호는
 * **총 자릿수 10 이상**을 요구해 `2014-03-15` 같은 날짜를 통과시킨다.
 */

/**
 * 본문 상한. **폭주 방어선이지 형식이 아니다** — 화면에 상시 카운터를 두지 않는 이유다.
 * 5,000자는 "채워야 할 목표"가 아니라 "여기까지는 마음껏"이다.
 *
 * 서버(`memories.js`)와 ③ 쓰기 화면이 **같은 숫자와 같은 세는 법**을 봐야 한다.
 * 한쪽에만 박아두면 언젠가 서버만 바뀌고, 사람은 다 쓴 글을 올리는 순간에야 거부당한다.
 */
export const BODY_MAX = 5000;

/**
 * 글자를 센다. **코드포인트 단위** — Postgres `char_length` 와 같은 기준이다.
 *
 * `String.prototype.length` 는 UTF-16 단위라 이모지를 2로 센다. HTML `maxlength` 도
 * 마찬가지여서, 그걸 5000 으로 걸면 **이모지를 쓰는 사람만 2,500자에서 잘린다.**
 * 그래서 쓰기 화면도 `maxlength` 가 아니라 이 함수로 센다.
 *
 * @param {string} s
 * @returns {number}
 */
export function bodyLength(s) {
  return [...s].length;
}

/**
 * 검출기 목록. 위에 있을수록 우선이며, 구간이 겹치면 위쪽이 이긴다.
 * (`01012345678`은 전화번호이자 무하이픈 계좌꼴이지만 전화번호로만 보고한다)
 */
const DETECTORS = [
  {
    id: 'phone',
    label: '전화번호',
    re: /01[0-9]-?\d{3,4}-?\d{4}/g,
    accept: () => true,
  },
  {
    id: 'account',
    label: '계좌번호로 보이는 숫자',
    re: /\b\d{2,6}-\d{2,6}-\d{2,8}\b/g,
    // 날짜(YYYY-MM-DD = 8자리)를 걸러내려고 자릿수 하한을 둔다.
    accept: (m) => m.replace(/\D/g, '').length >= 10,
  },
  {
    id: 'account',
    label: '계좌번호로 보이는 숫자',
    re: /\b\d{11,16}\b/g,
    accept: () => true,
  },
  {
    id: 'email',
    label: '이메일',
    re: /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g,
    accept: () => true,
  },
];

/**
 * 본문에서 PII로 보이는 구간을 찾는다.
 *
 * @param {string} text - 검사할 본문
 * @returns {{id: string, label: string, match: string, index: number, length: number}[]}
 *   시작 위치 오름차순. 비어 있으면 통과.
 */
export function detectPII(text) {
  if (typeof text !== 'string' || text.length === 0) return [];

  /** @type {{id:string,label:string,match:string,index:number,length:number}[]} */
  const hits = [];

  for (const det of DETECTORS) {
    // 검출기마다 lastIndex가 남지 않도록 매번 새로 만든다.
    const re = new RegExp(det.re.source, det.re.flags);
    let m;
    while ((m = re.exec(text)) !== null) {
      if (m[0].length === 0) {
        re.lastIndex += 1;
        continue;
      }
      if (!det.accept(m[0])) continue;

      const start = m.index;
      const end = start + m[0].length;
      // 이미 보고한 구간과 겹치면 버린다 — 우선순위가 높은 쪽이 먼저 들어와 있다.
      const overlaps = hits.some((h) => start < h.index + h.length && h.index < end);
      if (overlaps) continue;

      hits.push({ id: det.id, label: det.label, match: m[0], index: start, length: m[0].length });
    }
  }

  return hits.sort((a, b) => a.index - b.index);
}

/**
 * 검출 결과를 사람이 읽을 한 줄로. 로그·CLI용이며 화면 문구가 아니다.
 * **원문 조각을 로그에 남기지 않는다** — 그게 PII다.
 *
 * @param {ReturnType<typeof detectPII>} hits
 * @returns {string}
 */
export function summarizePII(hits) {
  if (hits.length === 0) return 'clean';
  const counts = new Map();
  for (const h of hits) counts.set(h.label, (counts.get(h.label) ?? 0) + 1);
  return [...counts].map(([label, n]) => `${label} ${n}건`).join(', ');
}
