#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

: "${CAPTURE_URL:?Set CAPTURE_URL}" 
: "${CAPTURE_DIR:?Set CAPTURE_DIR}"

run_timed() {
  /usr/bin/time -p "$@"
}

run_timed mkdir -p "$CAPTURE_DIR"

export CAPTURE_URL CAPTURE_DIR
export NODE_PATH="$HOME/.local/share/omgithub-playwright/node_modules"

run_timed node <<'JS'
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

(async () => {
  const url = process.env.CAPTURE_URL;
  const out = process.env.CAPTURE_DIR;
  const runtime = path.join(process.env.HOME, '.local/share/omgithub-playwright');
  const displayFile = path.join(runtime, 'display');
  if (process.platform === 'linux') process.env.DISPLAY ||= ':' + fs.readFileSync(displayFile, 'utf8').trim();

  let browser;
  try {
    const config = JSON.parse(fs.readFileSync(path.join(runtime, 'linux.json'), 'utf8'));
    try {
      browser = await chromium.launch({ ...config.browser.launchOptions, timeout: 30000 });
    } catch (error) {
      console.error('Temporary browser launch failure:', error.message);
      process.exitCode = 75;
      return;
    }

    for (const [name, width, height] of [['desktop', 1440, 900], ['mobile', 390, 844]]) {
      let page;
      try {
        page = await browser.newPage({ viewport: { width, height } });
        page.setDefaultTimeout(30000);
        const response = await page.goto(url, { waitUntil: 'load', timeout: 45000 });
        if (!response || !response.ok()) {
          const status = response ? response.status() : 0;
          console.error(`Navigation failure HTTP ${status}: ${url}`);
          process.exitCode = [408, 429, 500, 502, 503, 504].includes(status) ? 75 : 1;
          return;
        }
        await page.locator('body').waitFor({ state: 'visible', timeout: 30000 });
        await page.waitForFunction(() => document.fonts.status === 'loaded', null, { timeout: 30000 });
        await page.waitForTimeout(1200);
        await page.screenshot({ path: path.join(out, `final-${name}.png`), fullPage: true, timeout: 30000 });
        console.log(`Captured ${name}: ${path.join(out, `final-${name}.png`)}`);
      } catch (error) {
        const transient = error.name === 'TimeoutError' || /net::ERR|navigation|Target closed|browser.*closed/i.test(error.message);
        console.error(`Capture ${name} failure:`, error.message);
        process.exitCode = transient ? 75 : 1;
        return;
      } finally {
        if (page) await page.close().catch(() => {});
      }
    }
  } catch (error) {
    console.error('Capture script defect:', error);
    process.exitCode = 1;
  } finally {
    if (browser) await browser.close().catch(error => {
      console.error('Browser close failure:', error.message);
      process.exitCode ||= 75;
    });
  }
})();
JS
