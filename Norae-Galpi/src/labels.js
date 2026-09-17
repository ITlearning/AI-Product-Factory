/**
 * 계절·시절 라벨 — 스키마 CHECK 제약, 시드 검증, 화면 칩이 전부 여기를 본다.
 *
 * ## 시절이 6개인 이유 (rev.5, 실측으로 늘어났다)
 * 원래 5개였고 `스무 살 무렵`이 있었다. 2026-09-16 드라이런에서
 * 「Credit」의 기억이 **군생활**인데 받을 라벨이 없었고 — "군대는 성별이 갈려서 뺐다"는
 * 판단이 틀렸다, 실제 기억의 1/5이었다 — 「골목길 어귀에서」·「나무」 두 편이
 * **대학**인데 `스무 살 무렵`이 억지로 받았다.
 *
 * 연도가 아니라 인생 단계인 이유 — 사람들은 정확한 연도를 기억하지 못하고,
 * "2014년"은 정보지만 "고등학교 때"는 감정이며, 세대를 가로질러 같은 라벨에 모인다.
 *
 * **라벨은 전부 선택이고, 안 붙는 글이 많은 게 정상이다.** 시드 11편 중 계절이 붙은 건 2편뿐이다.
 */

/** 계절. `지금 계절` 정렬의 우선순위 기준값이기도 하다. */
export const SEASONS = ['spring', 'summer', 'autumn', 'winter'];

/** @type {Record<string, string>} 화면 표기 */
export const SEASON_LABELS = {
  spring: '봄',
  summer: '여름',
  autumn: '가을',
  winter: '겨울',
};

/**
 * 시절 6개.
 *
 * 설계 본문(rev.5)이 `어릴 때 · 학창시절 · 대학 때 · 군생활 · 사회 초년 · 요즘`으로 확정했는데,
 * 같은 문서의 스키마 초안은 rev.4의 5개(`child,school,twenties,career,now`)가 그대로 남아 있었다.
 * 시드의 「Credit」(군생활)과 「골목길 어귀에서」·「나무」(대학 때)가 그 5개로는 들어가지 않아
 * 본문 쪽을 정본으로 잡고 `twenties` → `university` + `military`로 고쳤다.
 */
export const ERAS = ['child', 'school', 'university', 'military', 'career', 'now'];

/** @type {Record<string, string>} 화면 표기 */
export const ERA_LABELS = {
  child: '어릴 때',
  school: '학창시절',
  university: '대학 때',
  military: '군생활',
  career: '사회 초년',
  now: '요즘',
};

/** 북반구 기준. 계절 기본 정렬이 한국 한정인 이유이기도 하다(i18n은 v1 범위 밖). */
export function currentSeason(date = new Date()) {
  const month = date.getMonth() + 1;
  if (month >= 3 && month <= 5) return 'spring';
  if (month >= 6 && month <= 8) return 'summer';
  if (month >= 9 && month <= 11) return 'autumn';
  return 'winter';
}
