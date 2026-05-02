// Puppeteer 기반 HTML → PNG 렌더 — clip으로 정확히 잘라서 viewport 오차 우회.
//
// 사용:
//   node marketing/render.js                # carousel-1~5 일괄
//   node marketing/render.js carousel-3     # 단일
//   node marketing/render.js story-1        # 1080×1920 자동
//
// prefix별 사이즈:
//   story-*   → 1080×1920
//   twitter-* → 1200×675
//   그 외      → 1080×1080

import puppeteer from 'puppeteer';
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEMPLATE_DIR = path.join(__dirname, 'templates');
const OUTPUT_DIR = path.join(__dirname, 'output');

fs.mkdirSync(OUTPUT_DIR, { recursive: true });

function sizeFor(name) {
  if (name.startsWith('story')) return { width: 1080, height: 1920 };
  if (name.startsWith('twitter')) return { width: 1200, height: 675 };
  return { width: 1080, height: 1080 };
}

async function render(browser, name) {
  const template = path.join(TEMPLATE_DIR, `${name}.html`);
  const output = path.join(OUTPUT_DIR, `${name}.png`);

  if (!fs.existsSync(template)) {
    console.log(`skip: ${template} not found`);
    return;
  }

  const { width, height } = sizeFor(name);
  console.log(`rendering: ${name} (${width}×${height})`);

  const page = await browser.newPage();
  await page.setViewport({ width, height, deviceScaleFactor: 1 });
  await page.goto(`file://${template}`, { waitUntil: 'networkidle0' });
  // 폰트 CDN 로드 완료 대기
  await page.evaluate(() => document.fonts.ready);
  // safety margin
  await new Promise((r) => setTimeout(r, 500));

  await page.screenshot({
    path: output,
    clip: { x: 0, y: 0, width, height },
    omitBackground: false,
  });
  await page.close();

  const stat = fs.statSync(output);
  console.log(`  → ${output} (${(stat.size / 1024).toFixed(0)}K)`);
}

const args = process.argv.slice(2);
const targets = args.length > 0 ? args : ['carousel-1', 'carousel-2', 'carousel-3', 'carousel-4', 'carousel-5'];

const browser = await puppeteer.launch({ headless: 'new' });
try {
  for (const name of targets) {
    await render(browser, name);
  }
} finally {
  await browser.close();
}

console.log('\n✅ Done.');
