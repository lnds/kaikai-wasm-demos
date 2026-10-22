# kaikai on WebAssembly — demos

[kaikai](https://github.com/lnds/kaikai) is a statically typed functional language with algebraic effects as a
first-class primitive, Elixir-style pipelines, and native compilation through LLVM.
This repository collects small kaikai programs built for the browser with `--target=wasm32-browser`.

| Demo | What it shows |
| --- | --- |
| [mandelbrot](demos/mandelbrot/main.kai) | The Mandelbrot set in ASCII, shaded by escape time with plain `Real` arithmetic. |
| [life](demos/life/main.kai) | Conway's Game of Life on a torus, stored in a `Vec[Bool]`. |
| [primes](demos/primes/main.kai) | An endless lazy sieve (`lazy [2..]`) feeding a prime table, twin primes and an Ulam spiral. |
| [maze](demos/maze/main.kai) | A maze carved by a seeded depth-first backtracker, solved by breadth-first search. |
| [queens](demos/queens/main.kai) | Every N-queens solution up to N = 10 with the flat-map pipe `\|\|`, plus a drawn board. |
| [plot](demos/plot/main.kai) | Text-art plots of sin, cos and a damped oscillation inside its envelope. |
| [calc](demos/calc/main.kai) | A parser and evaluator that only perform effects; handlers decide about errors, variables and tracing. |

Every demo is a plain program that computes and prints: what it writes to `Stdout` lands in a
`<pre>` on its page. The page also shows the program's source.

## Requirements

- **kaikai main (next release)** — the first release that ships `kai build --target=wasm32-browser`.
  The first wasm build downloads wasi-sdk 34 into the user cache and verifies its checksum.
- A browser with WebAssembly exception handling (exnref): Chrome/Edge 137+, Firefox 131+, Safari 18.4+.
- `node` for `check.sh` (an older node needs `--experimental-wasm-exnref`; `check.sh` retries with it).
- `python3` (or any static file server) to serve the site locally.

## Build

```sh
./build.sh                 # builds every demo into site/<name>/ and writes site/index.html
KAI=/path/to/kai ./build.sh   # use a specific kai binary
```

Each `site/<name>/` holds `app.wasm`, the `app.mjs`/`kai_host.mjs` loader, the plain `app.html`
that `kai` generates, and an `index.html` page with the output and the source.

## Serve locally

WebAssembly modules must be fetched over HTTP, not opened from `file://`:

```sh
python3 -m http.server 8000 --directory site
# open http://127.0.0.1:8000/
```

## Check

```sh
./check.sh              # build, run each demo under node, diff against expected.txt
./check.sh maze calc    # only some demos
./check.sh --update     # regenerate expected.txt from `kai run` on the host, then check
```

`demos/<name>/expected.txt` is the output of `kai run main.kai` on the host; the wasm build must
print exactly the same bytes.

## Adding a demo

1. Create `demos/<name>/main.kai` and a `demos/<name>/README.md` whose `# Title` and first
   paragraph become the gallery card.
2. Add `<name>` to `demos.txt` (it sets the gallery order).
3. Run `./check.sh --update <name>` to record its expected output.

A demo that needs its own markup can ship `demos/<name>/page.html`; `build.sh` uses it instead of
the generated page. It must keep `<pre id="kai-stdout">` (where `Stdout` goes) and
`<script type="module" src="app.mjs"></script>`.

Phase-1 limits: no `File`, `Stdin`, sockets, signals or fibers (`spawn`) on the page, and no
handler that keeps `resume` as a value; `Clock.sleep` stops at run time; non-tail recursion is bounded by the engine's stack (about 6000
frames in Chrome), so the demos loop with tail calls.

## Coming with phase 2

Phase 2 brings the DOM, timers and fetch to kaikai on the page. These demos are planned:

- **counter** — buttons that increment and decrement a value held in kaikai state.
- **live clock** — a clock redrawn every second from `Clock.now` and a timer.
- **fetch JSON** — load a JSON document over HTTP, decode it and render a table.

They slot into the same layout: a directory under `demos/`, a line in `demos.txt`, and a
`page.html` for the controls they need. A demo without `expected.txt` is built by `check.sh` but
not diffed, which covers demos whose output depends on the user or the clock.
