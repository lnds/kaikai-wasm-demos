# kaikai on WebAssembly — demos

[kaikai](https://github.com/lnds/kaikai) is a statically typed functional language with algebraic effects as a
first-class primitive, Elixir-style pipelines, and native compilation through LLVM.
This repository collects small kaikai programs built for the browser with `--target=wasm32-browser`.

### Canvas

| Demo | What it shows |
| --- | --- |
| [mandelbrot-canvas](demos/mandelbrot-canvas/main.kai) | The Mandelbrot set at 600×400 with smooth escape-time colouring, filled in row by row. |
| [life-canvas](demos/life-canvas/main.kai) | Game of Life on a 120×80 board at 25 generations a second: a Gosper glider gun, an acorn and an R-pentomino. |
| [plasma](demos/plasma/main.kai) | The demoscene plasma: three moving sine fields per pixel through a rotating palette, at 30 frames a second. |
| [maze-canvas](demos/maze-canvas/main.kai) | A maze carved live by a depth-first backtracker, flooded by breadth-first search and solved, forever. |

The canvas demos reach the page through `extern "js"` declarations: `document.getElementById`,
`.getContext`, `.fillRect`, `.fillStyle=`, `.textContent=`, with the canvas, its context and an
`ImageData` held as `extern "js" opaque` handles. `extern "js"` passes scalars, strings and handles,
not byte buffers, so the per-pixel demos write one packed colour per call into an `ImageData` through
[web/canvas.mjs](web/canvas.mjs), the `[js]` module their `kai.toml` names. They animate with
`Clock.sleep`, which parks on the page's event loop: a sleep of a frame or less wakes on the next
animation frame, and the page stays responsive throughout.

### Console

| Demo | What it shows |
| --- | --- |
| [mandelbrot](demos/mandelbrot/main.kai) | The Mandelbrot set in ASCII, shaded by escape time with plain `Real` arithmetic. |
| [life](demos/life/main.kai) | Conway's Game of Life on a torus, stored in a `Vec[Bool]`. |
| [primes](demos/primes/main.kai) | An endless lazy sieve (`lazy [2..]`) feeding a prime table, twin primes and an Ulam spiral. |
| [maze](demos/maze/main.kai) | A maze carved by a seeded depth-first backtracker, solved by breadth-first search. |
| [queens](demos/queens/main.kai) | Every N-queens solution up to N = 10 with the flat-map pipe `\|\|`, plus a drawn board. |
| [plot](demos/plot/main.kai) | Text-art plots of sin, cos and a damped oscillation inside its envelope. |
| [calc](demos/calc/main.kai) | A parser and evaluator that only perform effects; handlers decide about errors, variables and tracing. |

A console demo is a plain program that computes and prints: what it writes to `Stdout` lands in a
`<pre>` on its page. Every page also shows the program's source.

## Requirements

- **kaikai main (next release)** — `kai build --target=wasm32-browser` with `extern "js"` and waits
  that park on the page's event loop. The first wasm build downloads wasi-sdk 34 into the user cache
  and verifies its checksum.
- A browser with WebAssembly exception handling (exnref) and JavaScript Promise Integration (JSPI):
  Chrome/Edge 137+, Firefox 153+, Safari 27+. The canvas demos sleep, which needs JSPI; with current
  kaikai main every module imports it, the console demos included.
- `node` for `check.sh` (node 23 needs `--experimental-wasm-jspi`, an older node also
  `--experimental-wasm-exnref`; `check.sh` adds them).
- `python3` (or any static file server) to serve the site locally.

## Build

```sh
./build.sh                 # builds every demo into site/<name>/ and writes site/index.html
KAI=/path/to/kai ./build.sh   # use a specific kai binary
```

Each `site/<name>/` holds `app.wasm`, the `app.mjs`/`kai_host.mjs` loader, the plain `app.html`
that `kai` generates, the `app.js.mjs` copy of a `[js]` module when the demo has one, and an
`index.html` page with the output or the canvas, and the source.

## Serve locally

WebAssembly modules must be fetched over HTTP, not opened from `file://`:

```sh
python3 -m http.server 8000 --directory site
# open http://127.0.0.1:8000/
```

## Check

```sh
./check.sh              # build every demo and run it under node
./check.sh maze calc    # only some demos
./check.sh --update     # regenerate expected.txt from `kai run` on the host, then check
```

`demos/<name>/expected.txt` is the output of `kai run main.kai` on the host; a console demo's wasm
build must print exactly the same bytes. A canvas demo runs for two seconds against the stub page in
[web/smoke.mjs](web/smoke.mjs) — a canvas whose context counts the calls it receives — and passes
when it draws something without throwing.

## Adding a demo

1. Create `demos/<name>/main.kai` and a `demos/<name>/README.md` whose `# Title` and first
   paragraph become the gallery card.
2. Add `<name>` to `demos.txt` under `[canvas]` or `[console]` (the order sets the gallery's).
3. For a console demo, run `./check.sh --update <name>` to record its expected output.

A demo that needs its own markup ships `demos/<name>/page.html`; `build.sh` uses it instead of the
generated page, replacing a line `<!-- source -->` with the program's source. It must keep
`<pre id="kai-stdout">` (where `Stdout` goes) and `<script type="module" src="app.mjs"></script>`.
A canvas demo's page adds the `<canvas id="canvas">` it draws on, and its card shows
`demos/<name>/thumb.png`, a screenshot of the canvas. A demo that writes pixels lists the shared
module in its `kai.toml`:

```toml
name = "my-demo"
version = "0.1.0"

[js]
module = "../../web/canvas.mjs"
```

Limits on the page: no `File`, `Stdin`, sockets, processes or signals, and non-tail recursion is
bounded by the engine's stack (about 6000 frames in Chrome), so the demos loop with tail calls.

## Coming next

Keyboard and mouse events reach kaikai with the DOM bindings. These demos wait for them:

- **snake** — the classic, steered from the keyboard.
- **click-to-zoom Mandelbrot** — the canvas Mandelbrot, recentred and zoomed where you click.
- **fetch JSON** — load a JSON document over HTTP, decode it and render a table.
