import { createServer } from "http";
import { readFile } from "fs/promises";
import { extname, join, normalize } from "path";

const root = process.argv[2];
const port = Number(process.env.WEBAUDIO_PORT ?? 8197);
const playwrightModule = process.env.WEBAUDIO_PW ?? "playwright";
const { chromium } = await import(playwrightModule);

const mime = {
  ".html": "text/html",
  ".js": "application/javascript",
  ".mjs": "application/javascript",
  ".wasm": "application/wasm",
};

const server = createServer(async (req, res) => {
  try {
    const path = normalize(req.url.split("?")[0]).replace(/^\/+/, "") || "index.html";
    const data = await readFile(join(root, path));
    res.writeHead(200, { "content-type": mime[extname(path)] ?? "application/octet-stream" });
    res.end(data);
  } catch {
    res.writeHead(404);
    res.end();
  }
});
await new Promise((resolve) => server.listen(port, resolve));

const browser = await chromium.launch({
  args: ["--autoplay-policy=document-user-activation-required"],
  ...(process.env.WEBAUDIO_BROWSER ? { executablePath: process.env.WEBAUDIO_BROWSER } : {}),
});

const failures = [];
const expect = (condition, label, detail = "") => {
  console.log(`${condition ? "ok  " : "FAIL"} ${label}${detail === "" ? "" : ` (${detail})`}`);
  if (!condition) failures.push(label);
};

const instrument = () => {
  window.__contexts = [];
  window.__oscillators = 0;
  window.__gains = [];
  window.__masterLevels = [];
  const Original = window.AudioContext;
  window.__OriginalAudioContext = Original;
  window.AudioContext = class extends Original {
    constructor(...args) {
      super(...args);
      window.__contexts.push(this);
      console.log(`context-state ${this.state}`);
      this.addEventListener("statechange", () => console.log(`context-state ${this.state}`));
      const createOscillator = this.createOscillator.bind(this);
      const createGain = this.createGain.bind(this);
      this.createOscillator = () => {
        window.__oscillators++;
        return createOscillator();
      };
      this.createGain = () => {
        const node = createGain();
        window.__gains.push(node);
        if (window.__gains.length === 1) {
          const setValueAtTime = node.gain.setValueAtTime.bind(node.gain);
          node.gain.setValueAtTime = (value, at) => {
            window.__masterLevels.push(Math.round(value * 1000) / 1000);
            return setValueAtTime(value, at);
          };
        }
        return node;
      };
    }
  };
};

const openPage = (...initScripts) => preparePage(browser, initScripts);

const preparePage = async (host, initScripts) => {
  const page = await host.newPage();
  page.errors = [];
  page.warnings = [];
  page.logs = [];
  page.on("pageerror", (error) => page.errors.push(String(error)));
  page.on("console", (message) => {
    page.logs.push(message.text());
    if (message.text().includes("uncaught exception")) page.errors.push(message.text());
    if (message.type() === "error" && !message.location().url.endsWith("/absent.wav")) page.errors.push(message.text());
    if (message.type() === "warning") page.warnings.push(message.text());
  });
  await page.addInitScript(instrument);
  for (const script of initScripts) await page.addInitScript(script);
  await page.goto(`http://127.0.0.1:${port}/index.html`);
  if (!(await waitLog(page, "webaudio-hooks-ready", 60000))) throw new Error(`page never set up its hooks: ${page.errors.join(" | ")}`);
  return page;
};

const waitLog = async (page, text, timeout = 5000) => {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    if (page.logs.includes(text)) return true;
    await new Promise((resolve) => setTimeout(resolve, 5));
  }
  return false;
};

const waitRunning = (page) => waitLog(page, "context-state running");

const counts = (page) =>
  page.evaluate(() => ({
    contexts: window.__contexts.length,
    oscillators: window.__oscillators,
    state: window.__contexts[0]?.state ?? "none",
  }));

const attachMeter = (page) =>
  page.evaluate(() => {
    const context = window.__contexts[0];
    window.__meter = context.createAnalyser();
    window.__meter.fftSize = 2048;
    window.__gains[0].connect(window.__meter);
  });

const metered = (page, steps) =>
  page.evaluate(async (script) => {
    const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
    const peakOver = async (duration) => {
      const samples = new Float32Array(window.__meter.fftSize);
      let peak = 0;
      const end = performance.now() + duration;
      while (performance.now() < end) {
        window.__meter.getFloatTimeDomainData(samples);
        for (const s of samples) peak = Math.max(peak, Math.abs(s));
        await sleep(5);
      }
      return peak;
    };
    let last = 0;
    for (const [kind, value] of script) {
      if (kind === "call") globalThis.__webaudio[value]();
      if (kind === "sleep") await sleep(value);
      if (kind === "peak") last = await peakOver(value);
    }
    return last;
  }, steps);

const finish = async (page, label) => {
  expect(page.errors.length === 0, `${label}: no page errors`, page.errors.join(" | "));
  await page.close();
};

{
  const page = await openPage();
  await page.waitForFunction(() => globalThis.__webaudio.ready === true, null, { timeout: 90000 }).catch((error) => {
    console.error(`page never finished: ${page.errors.join(" | ")}`);
    throw error;
  });
  const state = await page.evaluate(() => ({
    failed: globalThis.__webaudio.failed ?? null,
    checks: { ...globalThis.__webaudio.checks },
    bench: { ...globalThis.__webaudio.bench },
  }));
  expect(state.failed === null, "renders and checks ran", state.failed ?? "");
  for (const name of ["notes", "knock", "garden", "routing", "space", "listener", "timbre", "sample", "worklet"]) {
    const same = await page.evaluate((n) => globalThis.__compare(n, false), name);
    expect(same.peak > 0.01, `${name}: reference is not silent`, `peak ${same.peak.toFixed(4)}`);
    expect(same.maxDiff < 1e-4, `${name}: Haskell graph matches raw Web Audio`, `max diff ${same.maxDiff}`);
    const mutated = await page.evaluate((n) => globalThis.__compare(n, true), name);
    expect(mutated.maxDiff > 0.01, `${name}: comparison notices a changed graph`, `max diff ${mutated.maxDiff.toFixed(4)}`);
  }
  for (const [name, value] of Object.entries(state.checks)) {
    if (name === "onEndedCount") expect(value === 50, "onEnded fires for each source", `${value}`);
    else expect(value === true, name);
  }
  const analysis = await page.evaluate(() => globalThis.__compareAnalysis());
  for (const [key, result] of Object.entries(analysis)) {
    expect(result.spread > 0, `analysis ${key}: reference is not empty`, `largest ${result.spread}, ${result.length} values`);
    expect(result.maxDiff < 1e-5, `analysis ${key}: Haskell reading matches raw Web Audio`, `max diff ${result.maxDiff}`);
  }
  console.log(`bench: ${JSON.stringify(state.bench)}`);
  await finish(page, "render page");
}

{
  const page = await openPage();
  await page.mouse.click(5, 5);
  await waitRunning(page);
  await page.evaluate(() => globalThis.__webaudio.live());
  await page.waitForFunction(() => globalThis.__webaudio.liveDone === true, null, { timeout: 30000 }).catch((error) => {
    console.error(`live checks never finished: ${page.errors.join(" | ")}`);
    throw error;
  });
  const live = await page.evaluate(() => ({ failed: globalThis.__webaudio.liveFailed ?? null, results: { ...globalThis.__webaudio.liveResults } }));
  expect(live.failed === null, "live checks ran", live.failed ?? "");
  const results = live.results;
  for (const name of ["contextAtRate", "contextCreated", "contextRunning", "baseLatencyPositive", "outputTimestamp"]) expect(results[name] === true, name);
  expect(results.streamPeak > 0.1, "a stream destination feeds a stream source", `peak ${results.streamPeak}`);
  expect(results.mediaPeak > 0.1, "a media element feeds a source node", `peak ${results.mediaPeak}`);
  const browserHasTrackSource = await page.evaluate(() => "createMediaStreamTrackSource" in AudioContext.prototype);
  expect(results.trackSourceAvailable === browserHasTrackSource, "track source follows the browser", `${results.trackSourceAvailable}`);
  const browserHasSink = await page.evaluate(() => "setSinkId" in AudioContext.prototype);
  expect(results.sinkAvailable === browserHasSink, "setSinkId detection follows the browser", `${results.sinkAvailable}`);
  if (results.sinkAvailable) expect(results.sinkSet === true, "setSinkId to the default device");
  const browserHasStats = await page.evaluate(() => "playbackStats" in AudioContext.prototype);
  expect(results.statsAvailable === browserHasStats, "playbackStats detection follows the browser", `${results.statsAvailable}`);
  if (results.statsAvailable) expect(results.statsRead === true, "playback stats read");
  await finish(page, "live page");
}

{
  const page = await openPage(() => {
    const control = new window.__OriginalAudioContext();
    setTimeout(() => console.log(`control ${control.state}`), 500);
  });
  expect(await waitLog(page, "control suspended", 3000), "control: a context without a gesture stays suspended", page.logs.filter((l) => l.startsWith("control")).join(" "));
  await page.close();
}

{
  const page = await openPage();
  await page.mouse.click(5, 5);
  expect(await waitRunning(page), "real click starts audio, with no script having run first", page.logs.join(" | "));
  const warned = page.warnings.filter((text) => text.includes("not allowed to start"));
  expect(warned.length === 0, "no autoplay warning", warned.join(" | "));
  let now = await counts(page);
  expect(now.contexts === 1, "one context", JSON.stringify(now));
  await attachMeter(page);
  const audible = await metered(page, [["call", "playLong"], ["peak", 120]]);
  expect(audible > 0.05 && audible <= 0.1201, "the note's signal is its gain times the player volume", audible.toFixed(4));
  now = await counts(page);
  expect(now.oscillators === 1, "a note after unlocking is scheduled", JSON.stringify(now));
  const cut = await metered(page, [["sleep", 500], ["call", "playLong"], ["sleep", 80], ["call", "mute"], ["sleep", 100], ["peak", 40]]);
  expect(cut < 1e-4, "mute cuts a ringing note", cut.toFixed(6));
  const beforeMuted = await counts(page);
  await page.evaluate(() => globalThis.__webaudio.play());
  now = await counts(page);
  expect(now.oscillators === beforeMuted.oscillators, "while muted no note is scheduled", JSON.stringify(now));
  const restored = await metered(page, [["sleep", 500], ["call", "unmute"], ["sleep", 20], ["call", "playLong"], ["peak", 120]]);
  expect(restored > 0.05 && restored <= 0.1201, "after unmuting notes are audible again", restored.toFixed(4));
  await finish(page, "mouse page");
}

{
  const page = await openPage();
  await page.keyboard.press("a");
  expect(await waitRunning(page), "real key press starts audio");
  await finish(page, "keyboard page");
}

{
  const touch = await browser.newContext({ hasTouch: true });
  const page = await preparePage(touch, []);
  await page.touchscreen.tap(5, 5);
  expect(await waitRunning(page), "real tap starts audio");
  const warned = page.warnings.filter((text) => text.includes("not allowed to start"));
  expect(warned.length === 0, "a tap causes no autoplay warning", warned.join(" | "));
  await finish(page, "touch page");
  await touch.close();
}

{
  const page = await openPage();
  await page.keyboard.press("Escape");
  await page.waitForTimeout(100);
  const warned = page.warnings.filter((text) => text.includes("not allowed to start"));
  expect(warned.length === 0 && !page.logs.some((line) => line.startsWith("context-state")), "a gesture that grants no activation creates no context", page.logs.join(" | "));
  await page.mouse.click(5, 5);
  expect(await waitRunning(page), "the next real gesture starts audio");
  await finish(page, "escape page");
}

{
  const page = await openPage();
  await page.mouse.click(5, 5);
  await waitRunning(page);
  const nested = await page.evaluate(() => {
    try {
      globalThis.__webaudio.clickElement(document.body);
      globalThis.__webaudio.playLong();
      return "ok";
    } catch (error) {
      return String(error);
    }
  });
  expect(nested === "ok", "a click from Haskell runs the gesture listener safely", nested);
  await finish(page, "nested click page");
}

{
  const page = await openPage();
  await page.evaluate(() => globalThis.__webaudio.mute());
  await page.mouse.click(5, 5);
  await waitRunning(page);
  await page.evaluate(() => globalThis.__webaudio.play());
  const muted = await page.evaluate(() => ({ levels: [...window.__masterLevels], oscillators: window.__oscillators }));
  expect(muted.levels.length === 1 && muted.levels[0] === 0 && muted.oscillators === 0, "muted before the first gesture stays silent", JSON.stringify(muted));
  await attachMeter(page);
  const restored = await metered(page, [["call", "unmute"], ["sleep", 20], ["call", "playLong"], ["peak", 120]]);
  expect(restored > 0.05 && restored <= 0.1201, "unmuting after a muted start is audible", restored.toFixed(4));
  await finish(page, "muted start page");
}

{
  const page = await openPage(() => {
    document.addEventListener(
      "pointerdown",
      () => {
        globalThis.__webaudio.play();
        window.__firstNote = { oscillators: window.__oscillators, state: window.__contexts[0]?.state };
      },
      { capture: true, once: true }
    );
  });
  await page.mouse.click(5, 5);
  await waitRunning(page);
  const first = await page.evaluate(() => window.__firstNote);
  expect(first?.oscillators === 1, "a note in the same gesture is kept", JSON.stringify(first));
  await finish(page, "first note page");
}

{
  const page = await openPage();
  await page.evaluate(() => globalThis.__webaudio.play());
  let now = await counts(page);
  expect(now.contexts === 0 && now.oscillators === 0, "before any gesture: nothing is created", JSON.stringify(now));
  await page.evaluate(() => window.dispatchEvent(new PointerEvent("pointerdown", { bubbles: true })));
  now = await counts(page);
  expect(now.contexts === 0, "a synthetic event does not create a context", JSON.stringify(now));
  await page.close();
}

{
  const page = await openPage();
  await page.mouse.click(5, 5);
  await waitRunning(page);
  await page.evaluate(() => window.__contexts[0].suspend());
  await waitLog(page, "context-state suspended");
  page.logs.length = 0;
  await page.waitForTimeout(400);
  await page.mouse.click(5, 5);
  expect(await waitRunning(page), "the next gesture resumes a suspended context");
  await page.evaluate(() => window.__contexts[0].suspend());
  await waitLog(page, "context-state suspended");
  page.logs.length = 0;
  await page.waitForTimeout(400);
  const before = await counts(page);
  await page.evaluate(() => globalThis.__webaudio.play());
  const after = await counts(page);
  expect(before.oscillators === after.oscillators, "a note while suspended long after a gesture is dropped", `${before.oscillators} -> ${after.oscillators}`);
  expect(await waitRunning(page), "that note also asks the context to resume");
  await page.evaluate(() => globalThis.__webaudio.play());
  const resumed = await counts(page);
  expect(resumed.oscillators === after.oscillators + 1, "notes play again after resuming", `${resumed.oscillators}`);
  await finish(page, "suspend page");
}

{
  const page = await openPage();
  await page.mouse.click(5, 5);
  await waitRunning(page);
  await page.evaluate(() => globalThis.__webaudio.closePlayer());
  expect(await waitLog(page, "context-state closed"), "closing closes the context");
  const closedTwice = await page.evaluate(() => {
    try {
      globalThis.__webaudio.closePlayer();
      return "ok";
    } catch (error) {
      return String(error);
    }
  });
  expect(closedTwice === "ok", "closing twice is safe", closedTwice);
  await page.mouse.click(5, 5);
  await page.waitForTimeout(50);
  const closed = await counts(page);
  expect(closed.contexts === 1, "after closing, gestures create nothing", JSON.stringify(closed));
  await finish(page, "close page");
}

await browser.close();
server.close();
if (failures.length > 0) {
  console.error(`FAILED: ${failures.join("; ")}`);
  process.exit(1);
}
console.log("PASS");
