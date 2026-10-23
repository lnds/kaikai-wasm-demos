// Runs a page demo under node against a stub document for a few seconds and
// reports what it drew. The stub canvas context counts the calls it receives;
// elements keep their text and the listeners the program registers.
//   node --experimental-wasm-jspi smoke.mjs <build-dir>/app.wasm [seconds] [smoke.json]
// smoke.json scripts the page: `events` are dispatched to an element at a time in
// milliseconds after start, and `expect` maps a selector to text it must contain at
// the end. Exits 1 if the program throws, draws nothing, or misses an expectation.
import { pathToFileURL } from "node:url";
import { dirname, join, resolve } from "node:path";
import { existsSync, readFileSync } from "node:fs";

const wasm = resolve(process.argv[2]);
const seconds = Number(process.argv[3] ?? 3);
const script = process.argv[4] ? JSON.parse(readFileSync(process.argv[4], "utf8")) : {};
const calls = new Map();
const count = (name) => calls.set(name, (calls.get(name) ?? 0) + 1);

// A 2D context that records every method call and accepts every property write.
function context(canvas) {
  return new Proxy({ canvas }, {
    get(target, key) {
      if (key in target) return target[key];
      return (...args) => count(String(key));
    },
    set(target, key, value) {
      target[key] = value;
      return true;
    },
  });
}

function element(tag, id = "") {
  const listeners = new Map();
  const el = {
    tagName: tag.toUpperCase(),
    id,
    width: 720,
    height: 480,
    textContent: "",
    children: [],
    style: { setProperty() {} },
    get clientWidth() { return this.width; },
    appendChild(c) { this.children.push(c); },
    remove() {},
    setAttribute(k, v) { this[k] = /^(width|height)$/.test(k) ? Number(v) : v; },
    getContext() { return context(el); },
    addEventListener(kind, fn) { listeners.set(kind, [...(listeners.get(kind) ?? []), fn]); },
    dispatch(kind, init) {
      const e = { type: kind, target: el, preventDefault() {}, ...init };
      (listeners.get(kind) ?? []).forEach((fn) => fn(e));
    },
  };
  return el;
}

const elements = new Map();
const byId = (id) => {
  if (!elements.has(id)) elements.set(id, element(id === "body" ? "body" : "div", id));
  return elements.get(id);
};
const find = (selector) => byId(selector.startsWith("#") ? selector.slice(1) : selector);
globalThis.document = {
  title: "",
  body: byId("body"),
  getElementById: byId,
  querySelector: find,
  createElement: (tag) => element(tag),
};
globalThis.ImageData = class {
  constructor(a, b, c) {
    if (typeof a === "number") [this.width, this.height, this.data] = [a, b, new Uint8ClampedArray(a * b * 4)];
    else [this.data, this.width, this.height] = [a, b, c];
  }
};
globalThis.OffscreenCanvas = class {
  constructor(w, h) {
    Object.assign(this, element("canvas"), { width: w, height: h });
  }
};
globalThis.requestAnimationFrame = (fn) => setTimeout(() => fn(performance.now()), 16);
globalThis.cancelAnimationFrame = (t) => clearTimeout(t);
const items = new Map();
globalThis.localStorage = {
  getItem: (k) => (items.has(k) ? items.get(k) : null),
  setItem: (k, v) => { items.set(k, String(v)); },
  removeItem: (k) => { items.delete(k); },
};

const dir = dirname(wasm);
const base = wasm.replace(/\.wasm$/, "");
const { run } = await import(pathToFileURL(join(dir, "kai_host.mjs")));
const glue = existsSync(`${base}.js.mjs`) ? await import(pathToFileURL(`${base}.js.mjs`)) : undefined;
if (glue?.pixels) {
  const set = glue.pixels.set;
  glue.pixels.set = (img, i, rgb) => { count("pixel"); set(img, i, rgb); };
}

for (const ev of script.events ?? []) {
  setTimeout(() => find(ev.to ?? "body").dispatch(ev.type, {
    key: ev.key, offsetX: ev.x ?? 0, offsetY: ev.y ?? 0,
  }), ev.at);
}

const report = (how) => {
  const drawn = [...calls].map(([k, v]) => `${k}=${v}`).join(" ");
  const missed = Object.entries(script.expect ?? {})
    .filter(([sel, text]) => !find(sel).textContent.includes(text))
    .map(([sel, text]) => `${sel} is "${find(sel).textContent}", expected "${text}"`);
  const texts = Object.keys(script.expect ?? {}).map((sel) => `${sel}="${find(sel).textContent}"`).join(" ");
  console.log(`${how}: ${drawn || "nothing drawn"}${texts ? " " + texts : ""}${missed.length ? "; " + missed.join("; ") : ""}`);
  process.exit((calls.size || script.expect) && !missed.length ? 0 : 1);
};

setTimeout(() => report(`still running after ${seconds}s`), seconds * 1000);
run(pathToFileURL(wasm), { imports: glue }).then(
  () => report("finished"),
  (e) => { console.error(e); process.exit(1); },
);
