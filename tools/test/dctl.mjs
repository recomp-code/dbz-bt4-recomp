// DBZ interactive headless session: node dctl.mjs <url> [headful]
// Append commands to dctl/cmd.txt: key KeyX.. | hold KeyX ms | shot name | snap /abs/path.png (canvas only) | log | eval <js> | prof secs name | quit
// The page log is also dumped to dctl/game.log every 3 s.
import puppeteer from 'puppeteer-core';
import fs from 'fs';
const [url = 'http://localhost:8091/?online=0', mode = 'headless'] = process.argv.slice(2);
const dir = new URL('./dctl/', import.meta.url).pathname;
fs.mkdirSync(dir, { recursive: true });
fs.writeFileSync(dir + 'cmd.txt', ''); fs.writeFileSync(dir + 'result.txt', '');
const logFile = fs.createWriteStream(dir + 'console.log');
const browser = await puppeteer.launch({
  executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  headless: mode !== 'headful',
  args: ['--window-size=1100,900', '--mute-audio', '--use-angle=metal', '--enable-gpu', '--ignore-gpu-blocklist', '--no-first-run', '--no-default-browser-check',
         '--disable-background-timer-throttling', '--disable-renderer-backgrounding', '--disable-backgrounding-occluded-windows'],
  defaultViewport: { width: 1060, height: 860 },
  userDataDir: process.env.HOME + '/NBAStreetRecomp/dbz/chrome-profile-headless',
});
fs.writeFileSync(dir + 'pid.txt', String(browser.process().pid));
const page = await browser.newPage();
const workers = [];
page.on('workercreated', (w) => workers.push({ url: w.url(), s: w.client }));
const t0 = Date.now();
const stamp = () => ((Date.now() - t0) / 1000).toFixed(1).padStart(6);
page.on('console', (m) => logFile.write(`${m.text()}\n`));
page.on('pageerror', (e) => logFile.write(`${stamp()} PAGEERROR: ${e.message}\n`));
await page.goto(url, { waitUntil: 'domcontentloaded' });
await page.evaluate(() => { const p = lines.push.bind(lines); lines.push = (...a) => { for (const x of a) console.log(x); return p(...a); }; });
await page.waitForSelector('#play', { timeout: 30000 }).then((b) => b.click());
setInterval(async () => { try { fs.writeFileSync(dir + 'game.log', await page.evaluate(() => lines.join('\n'))); } catch {} }, 3000);
let done = 0;
const result = (s) => fs.appendFileSync(dir + 'result.txt', `${stamp()} ${s}\n`);
for (;;) {
  await new Promise((r) => setTimeout(r, 300));
  const lines = fs.readFileSync(dir + 'cmd.txt', 'utf8').split('\n').filter(Boolean);
  for (; done < lines.length; done++) {
    const [cmd, ...rest] = lines[done].split(' ');
    try {
      if (cmd === 'key') for (const k of rest) { await page.keyboard.down(k); await new Promise((r) => setTimeout(r, 150)); await page.keyboard.up(k); await new Promise((r) => setTimeout(r, 400)); }
      else if (cmd === 'hold') { await page.keyboard.down(rest[0]); await new Promise((r) => setTimeout(r, +(rest[1] || 500))); await page.keyboard.up(rest[0]); }
      else if (cmd === 'shot') await page.screenshot({ path: `${dir}${rest[0] || 'shot'}.png`, clip: { x: 0, y: 0, width: 1060, height: 800 } });
      else if (cmd === 'snap') { const c = await page.$('#canvas'); await c.screenshot({ path: rest[0] }); }
      else if (cmd === 'log') fs.writeFileSync(dir + 'game.log', await page.evaluate(() => lines.join('\n')));
      else if (cmd === 'eval') result(JSON.stringify(await page.evaluate(rest.join(' '))));
      else if (cmd === 'prof') {
        const secs = +(rest[0] || 6);
        const all = [{ s: await page.createCDPSession(), name: 'page' }, ...workers.map((w, i) => ({ s: w.s, name: 'worker' + i }))];
        for (const w of all) { try { await w.s.send('Profiler.enable'); await w.s.send('Profiler.setSamplingInterval', { interval: 500 }); await w.s.send('Profiler.start'); } catch {} }
        await new Promise((r) => setTimeout(r, secs * 1000));
        let text = '';
        for (const w of all) {
          let p; try { p = (await w.s.send('Profiler.stop')).profile; } catch { continue; }
          const self = new Map(); const byId = new Map(p.nodes.map((n) => [n.id, n])); let total = 0, idle = 0;
          p.samples.forEach((id, k) => { const f = byId.get(id).callFrame.functionName || '(anon)'; const t = p.timeDeltas[k] || 0; self.set(f, (self.get(f) || 0) + t); total += t; if (f === '(idle)' || f === '(program)') idle += t; });
          if (total === 0) continue;
          text += `--- ${w.name}: busy ${(100 * (1 - idle / total)).toFixed(0)}%\n`;
          for (const [f, t] of [...self.entries()].sort((a, b) => b[1] - a[1]).slice(0, 120)) text += (100 * t / total).toFixed(1).padStart(5) + '%  ' + f.slice(0, 140) + '\n';
        }
        fs.writeFileSync(dir + (rest[1] || 'prof') + '.txt', text);
      }
      else if (cmd === 'quit') { await browser.close(); process.exit(0); }
      result('ok ' + lines[done]);
    } catch (e) { result('ERR ' + lines[done] + ' ' + e); }
  }
}
