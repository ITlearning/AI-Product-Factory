/**
 * 앱 셸 — 공통 헤더 + 라우팅.
 *
 * 화면 일곱
 *   ① 온보딩(곡 검색)  #/start
 *   ② 영상 확정        #/video   (+ iTunes에 없는 곡은 #/name 으로 이름 받기)
 *   ③④ 기억 적기+공개 확인 #/write
 *   ⑤ 홈 피드          #/
 *   ⑥ 곡 상세          #/song/:id
 *   ⑦ 내 갈피          #/mine
 */

import { el } from './ui/dom.js';
import { header, tabBar } from './ui/components.js';
import { currentRoute, onRouteChange } from './ui/router.js';
import { setNoindex, setTitle } from './ui/head.js';
import { installPress } from './ui/press.js';

import { feedScreen } from './ui/screens/feed.js';
import { startScreen } from './ui/screens/start.js';
import { videoScreen } from './ui/screens/video.js';
import { nameScreen } from './ui/screens/name.js';
import { writeScreen } from './ui/screens/write.js';
import { songScreen } from './ui/screens/song.js';
import { mineScreen } from './ui/screens/mine.js';

/**
 * @param {HTMLElement} root
 */
/**
 * 라우트 → 탭바에서 밝힐 칸.
 *
 * `song` 이 `home` 인 것이 중요하다 — ⑥ 곡 상세는 피드에서 들어간 **아래층**이지
 * 따로 선 화면이 아니다. 여기서 아무 칸도 안 밝히면 상세에 들어가는 순간
 * 탭바가 통째로 꺼진 것처럼 보여서 "내가 어디 있는지"를 잃는다.
 *
 * 없는 키(`start`·`video`·`name`·`write`)는 **탭바 자체를 감춘다.** 쓰는 중에
 * 다른 데로 새는 길을 깔아둘 이유가 없고, `적기` 탭이 자기 자신을 가리키게 된다.
 */
const TAB_OF = { '': 'home', song: 'home', mine: 'mine' };

/**
 * 화면별로 읽던 자리. **`←` 가 실제로 쓸모 있으려면 이게 있어야 한다.**
 *
 * 없으면 여덟 번째 카드에서 ⑥ 으로 들어갔다 나온 사람이 피드 맨 위로 떨어진다.
 * 그건 돌아가기가 아니라 처음부터 다시라, 한 번 겪으면 상세에 안 들어가게 된다.
 *
 * @type {Map<string, number>}
 */
const scrollMemory = new Map();

/**
 * @param {HTMLElement} root
 */
export function createApp(root) {
  const main = el('main', { attrs: { id: 'main' } });
  // 탭바도 한 번만 만든다. 라우트마다 새로 그리면 화면이 갈릴 때 **바닥이 같이 깜빡인다.**
  const tabs = tabBar();
  const hdr = header();
  // 헤더는 일곱 화면 전부에 있으므로 한 번 그리고 두고, 가운데만 갈아끼운다.
  root.replaceChildren(hdr, main, tabs);

  // 누름 피드백은 문서 하나에 위임으로 건다. fetch 뒤에 생기는 것까지 전부 걸린다.
  installPress(document);

  // 떠나기 직전 자리를 적으려면 "직전이 어디였는지"를 알아야 한다.
  // `hashchange` 는 이미 바뀐 뒤에 오므로 여기서 따로 들고 있는다.
  let lastKey = routeKey();
  // 앱 **안에서** 해시가 바뀐 횟수. `←` 가 `history.back()` 을 써도 되는지 가른다.
  let navCount = 0;

  render();
  onRouteChange(() => {
    navCount += 1;
    render();
  });

  function routeKey() {
    return location.hash || '#/';
  }

  function render() {
    const { name, param, query } = currentRoute();

    // 떠나온 화면의 스크롤을 적어둔다. 해시만 바뀐 시점이라 아직 그 화면의 위치다.
    scrollMemory.set(lastKey, window.scrollY);
    const key = routeKey();
    lastKey = key;

    // ⑥ 에만 `←`. 쓰기 흐름(①②③)은 각자 자기 앞 단계로 가는 규칙이 따로 있어
    // 같은 버튼을 달면 "어디로 가는 ←인지"가 화면마다 달라진다.
    hdr.setBack(
      name === 'song'
        ? () => {
            // 앱 안에서 한 번이라도 움직였으면 뒤에 우리 화면이 있다.
            // 0 이면 `#/song/12` 링크로 **바로 들어온 사람**이라, `history.back()` 은
            // 사이트 밖으로 나가버린다. 그때는 홈으로 보낸다.
            if (navCount > 0) history.back();
            else location.hash = '#/';
          }
        : null,
    );

    const tab = TAB_OF[name];
    tabs.hidden = !tab;
    tabs.setCurrent(tab ?? null);
    // 화면 바닥이 탭바에 가리지 않게 자리를 비운다. 탭바가 없는 쓰기 화면에서는
    // 그 여백도 같이 사라져야 `올리기` 버튼 밑이 휑해지지 않는다.
    document.body.classList.toggle('has-tabbar', Boolean(tab));

    // ⑥ 말고는 전부 색인 허용. 화면이 바뀔 때마다 되돌려 놓지 않으면
    // 상세를 한 번 열었다는 이유로 홈까지 noindex 가 된다.
    if (name !== 'song') setNoindex(false);

    // 열려 있던 시트를 걷는다. 시트는 `document.body` 에 붙어서 화면 교체(`main` 갈아끼우기)로
    // 사라지지 않는다. 안 걷으면 ④ 공개 확인을 띄운 채 워드마크로 홈에 간 사람이
    // **덮인 화면을 보고 아무것도 못 누르게 된다.**
    for (const stray of document.querySelectorAll('.sheet-backdrop')) stray.remove();

    // 화면이 바뀌면 위로. 해시 라우팅은 브라우저가 스크롤을 복원해주지 않는다.
    // 돌아온 화면이면 아래에서 읽던 자리로 되돌린다.
    window.scrollTo(0, 0);

    return restoreScroll(key, draw());

    function draw() {
      switch (name) {
        case 'start':
          setTitle('기억 적기');
          return startScreen(main);
        case 'video':
          setTitle('영상 고르기');
          return videoScreen(main);
        case 'name':
          setTitle('곡 이름');
          return nameScreen(main);
        case 'write':
          setTitle('기억 적기');
          return writeScreen(main, query);
        case 'song':
          setTitle(null);
          return songScreen(main, param);
        case 'mine':
          setTitle('내 갈피');
          return mineScreen(main);
        default:
          setTitle(null);
          return feedScreen(main, query);
      }
    }
  }
}

/**
 * 읽던 자리로 되돌린다.
 *
 * **그릴 때까지 기다려야 한다.** 화면들은 fetch 를 await 한 뒤에 DOM 을 갈아끼우므로,
 * 호출 직후에 스크롤하면 문서가 아직 한 화면 높이라 그냥 맨 위에 머문다.
 * 그래서 화면 함수가 돌려준 프로미스가 끝난 **다음 프레임**에 옮긴다
 * (레이아웃이 한 번 잡혀야 `scrollTo` 가 먹는다).
 *
 * 되돌릴 자리가 없으면 아무것도 안 한다 — 이미 위로 올려둔 상태다.
 *
 * @param {string} key - 라우트 키
 * @param {unknown} drawn - 화면 함수의 반환값 (프로미스일 수 있다)
 * @returns {unknown} 받은 것을 그대로 돌려준다
 */
function restoreScroll(key, drawn) {
  const y = scrollMemory.get(key);
  if (!y) return drawn;

  Promise.resolve(drawn)
    .then(() => {
      requestAnimationFrame(() => {
        // 그사이 다른 화면으로 또 넘어갔으면 건드리지 않는다. 느린 fetch 가 끝나면서
        // **이미 떠난 화면의 스크롤로** 사람을 끌어내리는 일이 없어야 한다.
        if ((location.hash || '#/') !== key) return;
        window.scrollTo(0, y);
      });
    })
    .catch(() => {});

  return drawn;
}
