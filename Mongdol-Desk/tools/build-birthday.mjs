// 생일 → 우리말 표(data/birthday.json). 앱 단어 목록에서 366일에 서로 다른 말을 하나씩 정해 둔다 — 같은 생일이면 누구나 같은 말.
//   node tools/build-birthday.mjs        (단어 목록이 바뀌면 다시 돌린다. 시드가 고정이라 같은 목록이면 같은 표.)
import { readFileSync, writeFileSync } from 'node:fs';

const src = JSON.parse(readFileSync(new URL('../../Color-Moments/Shared/Word/words.json', import.meta.url), 'utf8'));
const retired = new Set(src.retired);
const GROUPS = new Set(['빛·하늘', '날씨', '계절', '꽃·풀·나무', '물·땅', '마음·순간', '때']);
// 생일에 받으면 서운한 말 — 낱말·뜻풀이 어디에 있어도 뺀다.
const SAD = /궂|추위|싸늘|쓸쓸|외로|눈물|근심|시름|슬프|슬픔|아프|아픔|죽|병|고생|가난|다툼|싸움|미움|성나|화가|거칠|사나|매섭|매운|칼바람|모진|서럽|설움|한숨|걱정|두려|무섭|어둠|어둑|캄캄|그믐|흐리|궂은|눅눅|진눈|된서리|우박|폭|가뭄|장마|천둥|벼락|떨|시린|으스스|을씨년|헛|잃|버림|빈털|뒤척|선잠|토라|심술|투정|짜증|트집|핀잔|꾸중|부끄|창피|멍|게으|늦잠|코골|잠꼬대|하품|매서|찬 바람|세차|거세|퍼붓|억수|몹시 심한|어두운|탁한|혼자|버릇없|흙투성/;
// 밋밋하거나 생일에 어울리지 않는 말, 뜻풀이가 다른 뜻으로 붙은 말(첫눈·꽃비·해님 — 앱 데이터에서 고칠 것).
const SKIP = new Set(('채찍비 작살비 비보라 먹구름 먹구름장 장맛날 찜통더위 불더위 강더위 한더위 무더위 진날 회오리 황소바람 응달쪽 찬비 한둔 밤샘 쪽잠 토막잠 새우잠 고주박잠 '
  + '맞바람 눈바람 구름밤 줄비 날파람 남폿불 낟가리 맛술 깍지 목물 보람 해님 꽃비 첫눈 일재미 간직 흐름 요모조모 구경 거품 잘자리 눈자라기 엉겁결 낌새 몸짓 뒷이야기 '
  + '뒷그림자 불볕 땀방울 콧바람 맨땅 맨얼굴 등걸불 깜박불 한잠 잠맛 한소나기 빗속 빗길 비구름 눈기운 빗기운 온새미 배동바지 김장철 모래 나무 구름 바다 가을 더위 얼음 '
  + '보라 어린이날 어버이날 한가위 설날 단오 동지 대보름 칠석 매얼음 너테 묵은눈 얼음판 땅바람 갯바람 냇바람 벌바람 골바람 밤바람 거먕빛 가짓빛 대춧빛 구릿빛 노른빛 '
  + '밤불 부축 잿빛 번개 매지구름 곁때 으스름달 으스름달밤 혼자 덤불 누런빛 응달 그늘 가마솥더위 작달비 된소나기 된더위 빗줄기 줄번개 우레 칼잠 살바람 찬결 날씨 여름 하늘 안개 송이 우물 옛글 이것저것 이모저모 겹겹 갈피갈피 끝자락 맨손 치카치카 입엣말 입속말 응석 논두렁 패암 내친걸음 때깔 졸음 꾸벅잠 잠기운 풋잠 온밤 민얼굴 땀송이 잔눈 아쉬움 '
  + '바람길 하늘길 여울물 개펄 갯벌 갯가 기슭 맨눈 잔돌 돌멩이 징검돌 하룻밤 긴긴밤 밤잠 귀잠 봄잠 꿈나라 꿈속 따지기 보릿가을 보리누름 겨울나기 여름나기 열매철').split(' '));
// 계절 표시가 없는 말도 낱말에 계절이 보이면 그 철에만 쓴다(6월에 함박눈이 나오지 않게).
const HINT = [
  ['winter', /눈$|눈비|눈안개|눈보라|눈발|눈꽃|눈송이|함박눈|가루눈|눈가루|눈밭|눈벌|눈덩이|눈석임|발등눈|자국눈|풋눈|얼음|서리|성에|고드름|겨울|상고대/],
  ['summer', /더위|여름|장마|소나기|매미|뙤약볕|반딧불|물놀이/],
  ['spring', /봄|새싹|새잎|햇잎|어린잎|꽃샘|벚꽃|진달래|민들레|할미꽃|제비꽃|움싹|풀싹|해쑥|꽃망울|몽우리|꽃봉오리|이팝/],
  ['autumn', /가을|단풍|낙엽|서늘|도토리|밤송이|메밀꽃|갈대|까치밥|무서리|첫서리|가랑잎/],
];
const MEANT = [['winter', /눈이 |내린 눈|오는 눈|내리는 눈|겨울/], ['summer', /여름/], ['spring', /^봄|[^가-힣]봄|봄[에철볕]/], ['autumn', /가을/]];
// 뜻풀이가 철을 말하면 그쪽을 믿는다(무서리 = 늦가을, 낱말의 「서리」만 보면 겨울).
const hinted = (w) => { const m = MEANT.filter(([, re]) => re.test(w.meaning)); return (m.length ? m : HINT.filter(([, re]) => re.test(w.word))).map(([s]) => s); };
const SEASON = { 3: 'spring', 4: 'spring', 5: 'spring', 6: 'summer', 7: 'summer', 8: 'summer', 9: 'autumn', 10: 'autumn', 11: 'autumn', 12: 'winter', 1: 'winter', 2: 'winter' };

const words = src.words.filter((w) => !retired.has(w.id) && GROUPS.has(w.group) && !SAD.test(w.word + w.meaning) && !SKIP.has(w.word)
  && !w.hours && !w.rest && !w.moonAges && !w.lunar && !w.fallback);
const seen = new Set(), pool = words.filter((w) => !seen.has(w.word) && seen.add(w.word));

let seed = 20261012; // mulberry32 — 목록이 같으면 표도 같다
const rand = () => { seed |= 0; seed = (seed + 0x6D2B79F5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
const shuffle = (xs) => { for (let i = xs.length - 1; i > 0; i--) { const j = Math.floor(rand() * (i + 1)); [xs[i], xs[j]] = [xs[j], xs[i]]; } return xs; };
const fits = (w, m) => (w.months?.includes(m)) || w.seasons.includes(SEASON[m]) || hinted(w).includes(SEASON[m]);
const neutral = (w) => !w.months && w.seasons.length === 0 && hinted(w).length === 0;

const days = [];
for (let m = 1; m <= 12; m++) for (let d = 1; d <= new Date(2024, m, 0).getDate(); d++) days.push([m, d]);
const used = new Set(), table = {};
// 그 달에 맞는 말부터 날짜에 고루 나눠 주고(한 달에 다 몰리지 않게 섞어서), 모자란 날은 계절 없는 말로 채운다.
for (let m = 1; m <= 12; m++) {
  const ds = shuffle(days.filter(([mm]) => mm === m));
  const own = shuffle(pool.filter((w) => fits(w, m) && !used.has(w.word))).slice(0, Math.ceil(ds.length / 3));
  for (const [mm, d] of ds) {
    const w = own.shift() ?? shuffle(pool.filter((x) => neutral(x) && !used.has(x.word)))[0];
    used.add(w.word);
    table[String(mm).padStart(2, '0') + String(d).padStart(2, '0')] = { w: w.word, m: w.meaning };
  }
}
const out = Object.fromEntries(Object.keys(table).sort().map((k) => [k, table[k]]));
writeFileSync(new URL('../data/birthday.json', import.meta.url), JSON.stringify(out, null, 0) + '\n');
console.log(`${Object.keys(out).length}일 · 후보 ${pool.length}개`);
