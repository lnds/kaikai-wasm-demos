// Runs a canvas demo under node against a stub page for a few seconds and
// reports what it drew. Exits 1 if the program throws or draws nothing.
//   node --experimental-wasm-jspi smoke.mjs <build-dir>/app.wasm [seconds]
import { pathToFileURL } from "node:url";
import { dirname, join, resolve } from "node:path";
import { existsSync } from "node:fs";

const wasm = resolve(process.argv[2]);
const seconds = Number(process.argv[3] ?? 3);
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

function canvas(width, height) {
  const c = { width, height, textContent: "" };
  c.getContext = () => context(c);
  return c;
}

const elements = new Map();
globalThis.document = {
  title: "",
  getElementById(id) {
    if (!elements.has(id)) elements.set(id, canvas(600, 400));
    return elements.get(id);
  },
};
globalThis.ImageData = class {
  constructor(w, h) {
    this.width = w;
    this.height = h;
    this.data = new Uint8ClampedArray(w * h * 4);
  }
};
globalThis.OffscreenCanvas = class {
  constructor(w, h) {
    Object.assign(this, canvas(w, h));
  }
};

const dir = dirname(wasm);
const base = wasm.replace(/\.wasm$/, "");
const { run } = await import(pathToFileURL(join(dir, "kai_host.mjs")));
const glue = existsSync(`${base}.js.mjs`) ? await import(pathToFileURL(`${base}.js.mjs`)) : undefined;
if (glue?.pixels) {
  const set = glue.pixels.set;
  glue.pixels.set = (img, i, rgb) => { count("pixel"); set(img, i, rgb); };
}

const report = (how) => {
  const drawn = [...calls].map(([k, v]) => `${k}=${v}`).join(" ");
  console.log(`${how}: ${drawn || "nothing drawn"}`);
  process.exit(calls.size ? 0 : 1);
};

setTimeout(() => report(`still running after ${seconds}s`), seconds * 1000);
run(pathToFileURL(wasm), { imports: glue }).then(
  () => report("finished"),
  (e) => { console.error(e); process.exit(1); },
);
