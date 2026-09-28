/**
 * 정적 빌드 — index.html 과 src/ 를 dist/ 로 옮긴다.
 *
 * 번들러를 쓰지 않는다. 브라우저가 ES 모듈을 그대로 읽는다.
 * 이 제품은 "남이 쓴 세 줄이 읽고 싶게 생겼는가"가 전부라, 첫 페인트를 늦추는 값을
 * 치를 이유가 없다. (IBAD/app · Spending-Personality 와 같은 방식)
 *
 * **서버 전용 모듈이 브라우저로 새지 않는지 확인한다.** src/ 를 통째로 복사하므로
 * `node:` 를 import 하는 파일이 화면 코드에 딸려 들어가면 런타임에 터진다.
 */

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, '..');
const distRoot = path.join(projectRoot, 'dist');

/** 브라우저 진입점. 여기서 닿는 모듈은 전부 node 의존이 없어야 한다. */
const BROWSER_ENTRY = path.join(projectRoot, 'src', 'main.js');

/**
 * 진입점에서 실제로 도달하는 모듈을 따라가며 `node:` import 를 찾는다.
 *
 * @param {string} entry
 * @returns {string[]} 문제가 있는 파일의 프로젝트 상대 경로
 */
function findServerOnlyLeaks(entry) {
  const seen = new Set();
  const bad = [];
  const queue = [entry];

  while (queue.length > 0) {
    const file = queue.pop();
    if (seen.has(file) || !fs.existsSync(file)) continue;
    seen.add(file);

    const source = fs.readFileSync(file, 'utf8');

    if (/from\s+['"]node:/.test(source) || /require\(['"]node:/.test(source)) {
      bad.push(path.relative(projectRoot, file));
    }

    for (const m of source.matchAll(/from\s+['"](\.[^'"]+)['"]/g)) {
      queue.push(path.resolve(path.dirname(file), m[1]));
    }
  }
  return bad;
}

const leaks = findServerOnlyLeaks(BROWSER_ENTRY);
if (leaks.length > 0) {
  throw new Error(
    `브라우저 진입점에서 서버 전용 모듈에 닿는다 (node: import):\n  ${leaks.join('\n  ')}`,
  );
}

fs.rmSync(distRoot, { recursive: true, force: true });
fs.mkdirSync(distRoot, { recursive: true });
fs.cpSync(path.join(projectRoot, 'index.html'), path.join(distRoot, 'index.html'));
fs.cpSync(path.join(projectRoot, 'src'), path.join(distRoot, 'src'), { recursive: true });

const requiredOutputs = [
  path.join(distRoot, 'index.html'),
  path.join(distRoot, 'src', 'main.js'),
  path.join(distRoot, 'src', 'styles.css'),
];

for (const file of requiredOutputs) {
  if (!fs.existsSync(file)) {
    throw new Error(`Missing build output: ${path.relative(projectRoot, file)}`);
  }
}

console.log(`Built static app to ${path.relative(projectRoot, distRoot)}`);
