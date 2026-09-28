/**
 * 기기 비밀키 — 로그인이 없는 이 제품의 신원 전부.
 *
 * ## 복구 코드가 곧 키다
 * 설계: "복구 코드는 기기 비밀키 원본을 사람이 옮겨적을 수 있게 인코딩한 것"이고
 * **서버에 새로 저장하는 것은 아무것도 없다** — 여전히 해시만 갖는다.
 *
 * 그래서 키를 base64url 같은 걸로 만들고 따로 인코딩하지 않는다.
 * **처음부터 옮겨적을 수 있는 모양으로 만든다.** 그러면 둘이 어긋날 일이 없다.
 *
 *   갈피-4F7K-2M9Q-8XZP
 *
 * 12자 × 알파벳 30자 ≈ 2^58. 남이 찍어서 맞힐 수 있는 값이 아니다.
 * 헷갈리는 글자(I·L·O·U·0·1)를 뺐다 — 손으로 옮겨적는 게 이 코드의 유일한 용도라
 * `0`과 `O`가 섞이면 코드가 제 일을 못 한다.
 *
 * ## 대가
 * 코드가 곧 키이므로 **유출되면 타인이 내 글을 지울 수 있다.**
 * 서버에 개인정보를 한 건도 두지 않는 대신 치르는 값이고, 로그인 방식과의 맞교환이다.
 */

const STORAGE_KEY = 'norae-galpi.device-key';
const PREFIX = '갈피';
/** 헷갈리는 글자를 뺀 30자. */
const ALPHABET = '23456789ABCDEFGHJKMNPQRSTVWXYZ';
const GROUPS = 3;
const GROUP_LEN = 4;

/**
 * 새 키를 만든다. `crypto.getRandomValues` 로만 만든다 — `Math.random()` 은 신원에 못 쓴다.
 *
 * @returns {string} 예: `갈피-4F7K-2M9Q-8XZP`
 */
export function createKey() {
  const bytes = new Uint32Array(GROUPS * GROUP_LEN);
  crypto.getRandomValues(bytes);

  const chars = [...bytes].map((n) => ALPHABET[n % ALPHABET.length]);
  const groups = [];
  for (let i = 0; i < GROUPS; i++) {
    groups.push(chars.slice(i * GROUP_LEN, (i + 1) * GROUP_LEN).join(''));
  }
  return `${PREFIX}-${groups.join('-')}`;
}

/**
 * 사람이 옮겨적은 코드를 정본 모양으로 되돌린다.
 *
 * 하이픈을 빼먹거나, 소문자로 쓰거나, 접두사를 안 쓰거나, 공백을 섞어도 받는다.
 * 여기서 까다롭게 굴면 복구 코드가 있는데도 못 돌아오는 사람이 생긴다.
 *
 * @param {string} input
 * @returns {string|null} 정본 코드, 못 알아보면 null
 */
export function normalizeKey(input) {
  if (typeof input !== 'string') return null;

  const body = input
    .normalize('NFC')
    .replace(new RegExp(`^\\s*${PREFIX}`, 'u'), '')
    .toUpperCase()
    .replace(/[^0-9A-Z]/g, '');

  if (body.length !== GROUPS * GROUP_LEN) return null;
  if ([...body].some((c) => !ALPHABET.includes(c))) return null;

  const groups = [];
  for (let i = 0; i < GROUPS; i++) groups.push(body.slice(i * GROUP_LEN, (i + 1) * GROUP_LEN));
  return `${PREFIX}-${groups.join('-')}`;
}

/**
 * 저장된 키. 없으면 **만들지 않는다** — 읽기만 하는 사람에게 신원을 발급할 이유가 없다.
 *
 * @returns {string|null}
 */
export function readKey() {
  try {
    return localStorage.getItem(STORAGE_KEY);
  } catch {
    // 시크릿 모드·사이트 데이터 차단. 이 세션 동안만 메모리에 들고 간다.
    return memoryKey;
  }
}

let memoryKey = null;

/**
 * 키를 저장한다. localStorage 가 막혀 있어도 이 세션은 돌아가야 한다.
 *
 * @param {string} key
 */
export function writeKey(key) {
  memoryKey = key;
  try {
    localStorage.setItem(STORAGE_KEY, key);
  } catch {
    /* 저장이 막혀도 이 세션은 memoryKey 로 돈다. 새로고침하면 사라진다. */
  }
}

/**
 * 글을 쓰려는 순간 호출한다. 없으면 만들어 저장하고 돌려준다.
 *
 * @returns {{key: string, isNew: boolean}}
 */
export function ensureKey() {
  const existing = readKey();
  if (existing) return { key: existing, isNew: false };
  const key = createKey();
  writeKey(key);
  return { key, isNew: true };
}

/**
 * 복구 코드로 다른 기기의 글에 다시 닿는다.
 *
 * @param {string} input
 * @returns {string|null} 복원한 키
 */
export function restoreKey(input) {
  const key = normalizeKey(input);
  if (key) writeKey(key);
  return key;
}

const SEEN_KEY = 'norae-galpi.recovery-seen';

/**
 * 복구 코드를 이미 보여줬는가.
 *
 * "키를 방금 만들었는가"로 판단하면 안 된다. 키는 **올리기를 누른 순간** 만들어지는데,
 * 그 요청이 실패하면(PII·레이트리밋·네트워크) 키만 남고 화면은 안 뜬다. 그다음 성공에서는
 * 더 이상 새 키가 아니라서 **복구 코드를 영영 못 보게 된다.**
 * 그래서 "첫 글이 올라간 순간"을 따로 기억한다.
 *
 * @returns {boolean}
 */
export function hasSeenRecovery() {
  try {
    return localStorage.getItem(SEEN_KEY) === '1';
  } catch {
    return seenInMemory;
  }
}

let seenInMemory = false;

export function markRecoverySeen() {
  seenInMemory = true;
  try {
    localStorage.setItem(SEEN_KEY, '1');
  } catch {
    /* 못 적어도 ⑦ 내 갈피에서 언제든 다시 볼 수 있다 */
  }
}
