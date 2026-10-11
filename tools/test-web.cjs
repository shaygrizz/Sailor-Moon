// Run with NODE_PATH pointing to the installed Playwright package directory.
const { chromium } = require('playwright');
const fs = require('node:fs');
(async () => {
  fs.mkdirSync('artifacts', {recursive: true});
  fs.writeFileSync('artifacts/.gdignore', '');
  const browser = await chromium.launch({channel: 'chrome', headless: true, args: ['--enable-webgl', '--use-angle=swiftshader', '--enable-unsafe-swiftshader']});
  const page = await browser.newPage({viewport: {width: 1280, height: 720}, hasTouch: true});
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', e => { console.log('BROWSER', e.type(), e.text()); if (e.type() === 'error') errors.push(e.text()); });
  await page.goto('http://127.0.0.1:8060', {waitUntil:'networkidle'});
  await page.waitForFunction(() => !document.querySelector('#status'), null, {timeout: 60000});
  await page.waitForTimeout(1500);
  await page.screenshot({path:'artifacts/title-desktop.png'});
  await page.keyboard.press('Enter');
  for (let i=0; i<3; i++) { await page.waitForTimeout(400); await page.keyboard.press('Enter'); }
  await page.waitForTimeout(600);
  await page.screenshot({path:'artifacts/world-desktop.png'});
  await page.mouse.click(471, 330);
  await page.waitForTimeout(1400);
  await page.screenshot({path:'artifacts/dialogue-desktop.png'});
  for (let i=0; i<3; i++) { await page.waitForTimeout(350); await page.keyboard.press('Enter'); }
  await page.mouse.click(717, 402);
  await page.waitForTimeout(1700);
  await page.mouse.click(225, 355);
  await page.waitForTimeout(2500);
  await page.screenshot({path:'artifacts/dream-desktop.png'});
  await page.mouse.click(498, 323);
  await page.waitForTimeout(1700);
  await page.screenshot({path:'artifacts/battle-desktop.png'});
  await page.setViewportSize({width:390, height:844});
  await page.waitForTimeout(1000);
  await page.screenshot({path:'artifacts/battle-mobile.png'});
  await page.touchscreen.tap(270, 662);
  await page.waitForTimeout(400);
  await page.screenshot({path:'artifacts/target-mobile.png'});
  const storage = await page.evaluate(async () => {
    const snapshots = [];
    for (const entry of await indexedDB.databases()) {
      const db = await new Promise((resolve,reject) => { const r=indexedDB.open(entry.name); r.onsuccess=()=>resolve(r.result); r.onerror=()=>reject(r.error); });
      for (const name of db.objectStoreNames) {
        const store = db.transaction(name,'readonly').objectStore(name);
        const records = await new Promise((resolve,reject)=>{const r=store.getAll();r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error);});
        for (const record of records) {
          if (!record.contents) continue;
          try { const value=JSON.parse(new TextDecoder().decode(record.contents)); if(value.version && value.party) snapshots.push(value); } catch (_) {}
        }
      }
      db.close();
    }
    return snapshots;
  });
  if (!storage.some(s=>s.map==='dream' && s.quest_steps.first_star===2)) errors.push('Expected pre-battle autosave missing from IndexedDB');
  await page.reload({waitUntil:'networkidle'});
  await page.waitForFunction(() => !document.querySelector('#status'), null, {timeout:60000});
  await page.waitForTimeout(1000);
  await page.screenshot({path:'artifacts/title-mobile.png'});
  await page.keyboard.press('Tab');
  await page.keyboard.press('Enter');
  await page.waitForTimeout(1000);
  await page.screenshot({path:'artifacts/world-mobile.png'});
  const report = {errors, persistedSnapshots:storage.length, title: await page.title(), canvas: await page.locator('canvas').boundingBox()};
  fs.writeFileSync('artifacts/web-report.json', JSON.stringify(report,null,2));
  console.log(JSON.stringify(report));
  await browser.close();
  if (errors.length) process.exitCode=1;
})();
