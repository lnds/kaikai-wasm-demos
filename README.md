# kaikai on WebAssembly — demos

[kaikai](https://github.com/lnds/kaikai) is a statically typed functional language with algebraic effects as a
first-class primitive, Elixir-style pipelines, and native compilation through LLVM.
This repository collects small kaikai programs built for the browser with `--target=wasm32-browser`.

### On the page

| Demo | What it shows |
| --- | --- |
| [snake](demos/snake/main.kai) | A playable Snake: arrow keys or WASD, speed-up as it grows, pause, game over and restart with Space, best score kept in `localStorage`. |
| [mandelbrot-zoom](demos/mandelbrot-zoom/main.kai) | The Mandelbrot set that zooms in where you click (right-click or `-` zooms out, `R` resets), refined from coarse blocks to exact pixels while staying responsive. |
| [mandelbrot-canvas](demos/mandelbrot-canvas/main.kai) | The Mandelbrot set at 600×400 with smooth escape-time colouring, filled in a band of rows per frame. |
| [life-canvas](demos/life-canvas/main.kai) | Game of Life on a 120×80 board at 25 generations a second: a Gosper glider gun, an acorn and an R-pentomino. |
| [plasma](demos/plasma/main.kai) | The demoscene plasma: three moving sine fields per pixel through a rotating palette, on every animation frame. |
| [maze-canvas](demos/maze-canvas/main.kai) | A maze carved live by a depth-first backtracker, flooded by breadth-first search and solved, forever. |
| [counter-clock](demos/counter-clock/main.kai) | A click counter and a live clock: the DOM effects in their simplest form. |

## Interactive

The interactive demos use kaikai's browser stdlib. `web.run { … }` installs four effects answered
by the page: `Dom` (`web.dom`: query and build nodes, a 2D canvas, events), `Timer` (`web.timer`:
`now_ms`, `sleep_ms`, `animation_frame`, `every`), `Storage` (`web.storage`, over `localStorage`)
and `Fetch` (`web.fetch`). Nothing in JavaScript calls back into the program: `Dom.listen(node, "keydown")`
asks the page to queue events of a kind, and the program takes them as values, an
`Event { kind, key, x, y, target }`, with `Dom.next_event()` (which parks the program until one
arrives) or `Dom.poll_event()` (which returns `None` when the queue is empty).

- **snake** keeps the whole game in an immutable record stepped by a pure `tick`. Each
  `Timer.animation_frame` drains the queued keys with `poll_event`, runs the steps that are due, and
  draws the snake part of the way through its current step, so it glides between cells. Between
  games it parks on `next_event`. The best score goes to `Storage`.
- **mandelbrot-zoom** keeps an RGBA `Array[Byte]`, computes for a few milliseconds per frame, and
  draws it with one `Dom.put_pixels`. A click that arrives mid-render restarts at the new view on
  the next frame.
- **mandelbrot-canvas** and **plasma** draw the same way, with one `put_pixels` per frame; plasma
  writes a 200×125 buffer and lets the browser scale the canvas up.
- **counter-clock** reads a button's clicks and a `Timer.every` tick from the same queue and
  answers with `Dom.set_text`.

**life-canvas** and **maze-canvas** reach the page through their own `extern "js"` declarations
instead (`document.getElementById`, `.getContext`, `.fillRect`, `.textContent=`), with the canvas,
its context and an `ImageData` held as `extern "js" opaque` handles; life-canvas writes its pixels
one call at a time through [web/canvas.mjs](web/canvas.mjs), the `[js]` module its `kai.toml`
names. They animate with `Clock.sleep`, which parks on the page's event loop.

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

- **kaikai 0.172.0 or later**: `kai build --target=wasm32-browser` with `extern "js"` and the
  browser stdlib (`web.run`, `web.dom`, `web.timer`, `web.storage`). Use the first kaikai release
  that ships them, or later. The first wasm build downloads wasi-sdk 34 into the user cache and
  verifies its checksum.
- A browser with WebAssembly exception handling (exnref). A page that suspends (one that waits
  for events, frames or sleeps: every page in the first section) also needs JavaScript Promise
  Integration: Chrome/Edge 137+, Firefox 153+, Safari 27+. A page that never suspends, like the
  console demos, runs on any engine with exception handling: Chrome/Edge 137+, Firefox 131+,
  Safari 18.4+.
- `node` for `check.sh` (node 23 needs `--experimental-wasm-jspi` and `--experimental-wasm-exnref`;
  `check.sh` adds them).
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
build must print exactly the same bytes. A page demo runs for four seconds against the stub
document in [web/smoke.mjs](web/smoke.mjs): a canvas whose context counts the calls it receives,
and elements that keep their text and the listeners the program registers. A demo with a
`smoke.json` is fed the events it lists (keys, clicks) at set times, and its `expect` entries name
an element and text it must contain at the end. The demo passes when it draws something or meets
its expectations, without throwing.

## Adding a demo

1. Create `demos/<name>/main.kai` and a `demos/<name>/README.md` whose `# Title` and first
   paragraph become the gallery card.
2. Add `<name>` to `demos.txt` under `[canvas]` (the "On the page" section) or `[console]`; the
   order sets the gallery's.
3. For a console demo, run `./check.sh --update <name>` to record its expected output.

A demo that needs its own markup ships `demos/<name>/page.html`; `build.sh` uses it instead of the
generated page, replacing a line `<!-- source -->` with the program's source. It must keep
`<pre id="kai-stdout">` (where `Stdout` goes) and `<script type="module" src="app.mjs"></script>`.
A page demo adds the elements it draws on or listens to, and its card shows
`demos/<name>/thumb.png`, a screenshot. It may add a `smoke.json` for `check.sh`. A demo that
writes pixels through the shared `[js]` module rather than `Dom.put_pixels` lists it in its
`kai.toml`:

```toml
name = "my-demo"
version = "0.1.0"

[js]
module = "../../web/canvas.mjs"
```

Limits on the page: no `File`, `Stdin`, sockets, processes or signals, and non-tail recursion is
bounded by the engine's stack (about 6000 frames in Chrome), so the demos loop with tail calls.
