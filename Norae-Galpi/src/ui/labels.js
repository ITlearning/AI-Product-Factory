/**
 * 화면용 라벨 보조.
 *
 * 값 자체는 **`src/labels.js` 를 그대로 가져다 쓴다.** 그 모듈에는 node 의존이 없어
 * 브라우저에서 바로 돈다. 스키마 CHECK·시드 검증·화면 칩이 전부 한 파일을 보므로
 * 값이 어긋날 자리가 없다.
 */

export { SEASONS, SEASON_LABELS, ERAS, ERA_LABELS, currentSeason } from '../labels.js';

import { SEASON_LABELS, ERA_LABELS } from '../labels.js';

export const SORT_LABELS = {
  season: '지금 계절',
  recent: '최신',
  lasting: '오래 남은',
};

/**
 * 카드 발치에 붙는 한 줄. 둘 다 없으면 빈 문자열이고 **그게 정상이다** —
 * 사람들은 틀에 맞춰 적지 않고, 그때 그 기억이 뭐였는지 떠올려 적는다.
 *
 * @param {{season?: string|null, era?: string|null}} memory
 * @returns {string}
 */
export function labelLine(memory) {
  return [SEASON_LABELS[memory?.season], ERA_LABELS[memory?.era]].filter(Boolean).join(' · ');
}
