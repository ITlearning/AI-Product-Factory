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
 * @param {HTMLElement} root
 */
export function createApp(root) {
  const main = el('main', { attrs: { id: 'main' } });
  // 탭바도 한 번만 만든다. 라우트마다 새로 그리면 화면이 갈릴 때 **바닥이 같이 깜빡인다.**
  const tabs = tabBar();
  // 헤더는 일곱 화면 전부에 있으므로 한 번 그리고 두고, 가운데만 갈아끼운다.
  root.replaceChildren(header(), main, tabs);

  // 누름 피드백은 문서 하나에 위임으로 건다. fetch 뒤에 생기는 것까지 전부 걸린다.
  installPress(document);

  render();
  onRouteChange(render);

  function render() {
    const { name, param, query } = currentRoute();

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
    window.scrollTo(0, 0);

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
