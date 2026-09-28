/**
 * ①→②→③ 사이에 들고 다니는 초안.
 *
 * sessionStorage 에 둔다 — 새로고침이나 ②에서 유튜브 앱을 다녀와도 고른 곡이 살아 있어야 한다.
 * 모바일에서 링크 복사는 앱 왕복 여섯 단계라, 돌아왔을 때 처음부터 다시 검색해야 하면
 * 거기서 대부분 이탈한다.
 *
 * **기억 본문도 여기 잠깐 머문다.** 브라우저 밖으로는 안 나가고,
 * 글이 올라가면 지운다.
 */

const KEY = 'norae-galpi.draft';
let memory = {};

/** @returns {object} */
export function getDraft() {
  try {
    return JSON.parse(sessionStorage.getItem(KEY) ?? 'null') ?? memory;
  } catch {
    return memory;
  }
}

/** @param {object} patch */
export function setDraft(patch) {
  const next = { ...getDraft(), ...patch };
  memory = next;
  try {
    sessionStorage.setItem(KEY, JSON.stringify(next));
  } catch {
    /* 막혀 있어도 이 세션은 memory 로 돈다 */
  }
  return next;
}

export function clearDraft() {
  memory = {};
  try {
    sessionStorage.removeItem(KEY);
  } catch {
    /* 무해 */
  }
}
