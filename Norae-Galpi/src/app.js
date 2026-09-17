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
import { header } from './ui/components.js';
import { currentRoute, onRouteChange } from './ui/router.js';
import { setNoindex, setTitle } from './ui/head.js';

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
export function createApp(root) {
  const main = el('main', { attrs: { id: 'main' } });
  // 헤더는 일곱 화면 전부에 있으므로 한 번 그리고 두고, 아래만 갈아끼운다.
  root.replaceChildren(header(), main);

  render();
  onRouteChange(render);

  function render() {
    const { name, param, query } = currentRoute();

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
