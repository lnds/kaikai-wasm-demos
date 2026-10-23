#!/bin/sh
# Builds each demo in demos.txt for wasm32-browser and runs it under node.
# A console demo's output is diffed against demos/<name>/expected.txt, the
# output of `kai run` on the host; a console demo without expected.txt is only
# built. A page demo runs for a few seconds against a stub document
# (web/smoke.mjs), fed the events in its smoke.json when it has one, and passes
# when it draws or meets its expectations without throwing.
# Usage: ./check.sh [--update] [name...]   (KAI=path/to/kai)
#   --update  rewrites expected.txt from `kai run` before checking.
set -u

KAI="${KAI:-kai}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
OUT="$ROOT/out/check"
UPDATE=0

if [ "${1:-}" = "--update" ]; then
  UPDATE=1
  shift
fi

if [ $# -eq 0 ]; then
  set -- $(grep -v -e '^#' -e '^\[' "$ROOT/demos.txt")
fi

# The host refuses a module that imports `kai.needs_suspension` on an engine
# without JSPI; node 23 ships JSPI behind a flag.
JSPI=""
if ! node -e 'process.exit(typeof WebAssembly.Suspending === "function" ? 0 : 1)'; then
  JSPI="--experimental-wasm-jspi"
fi

is_canvas() {
  sed -n '/^\[canvas\]$/,/^\[/p' "$ROOT/demos.txt" | grep -qx "$1"
}

run_node() {
  if node $JSPI "$1/kai_host.mjs" "$1/app.wasm" > "$1/stdout.txt" 2> "$1/stderr.txt"; then
    return 0
  fi
  # Older node releases ship WebAssembly exception handling behind a flag.
  if grep -q exnref "$1/stderr.txt"; then
    node $JSPI --experimental-wasm-exnref "$1/kai_host.mjs" "$1/app.wasm" > "$1/stdout.txt" 2> "$1/stderr.txt"
  else
    return 1
  fi
}

smoke() {
  if node $JSPI "$ROOT/web/smoke.mjs" "$1/app.wasm" 4 ${2:-} > "$1/smoke.txt" 2>&1; then
    return 0
  fi
  if grep -q exnref "$1/smoke.txt"; then
    node $JSPI --experimental-wasm-exnref "$ROOT/web/smoke.mjs" "$1/app.wasm" 4 ${2:-} > "$1/smoke.txt" 2>&1
  else
    return 1
  fi
}

pass=0
fail=0
skip=0
for name in "$@"; do
  dir="$ROOT/demos/$name"
  build="$OUT/$name"
  mkdir -p "$build"
  if [ "$UPDATE" -eq 1 ]; then
    "$KAI" run "$dir/main.kai" > "$dir/expected.txt" 2> "$build/host-stderr.txt" || {
      echo "FAIL $name: kai run failed"; cat "$build/host-stderr.txt"; fail=$((fail + 1)); continue
    }
  fi
  if ! "$KAI" build --target=wasm32-browser "$dir/main.kai" -o "$build/app" > "$build/build.txt" 2>&1; then
    echo "FAIL $name: build"; cat "$build/build.txt"; fail=$((fail + 1)); continue
  fi
  if is_canvas "$name"; then
    script=""
    [ -f "$dir/smoke.json" ] && script="$dir/smoke.json"
    if smoke "$build" $script; then
      echo "ok   $name ($(cat "$build/smoke.txt"))"
      pass=$((pass + 1))
    else
      echo "FAIL $name: smoke"; cat "$build/smoke.txt"; fail=$((fail + 1))
    fi
    continue
  fi
  if [ ! -f "$dir/expected.txt" ]; then
    echo "skip $name: built, no expected.txt"; skip=$((skip + 1)); continue
  fi
  if ! run_node "$build"; then
    echo "FAIL $name: node"; cat "$build/stderr.txt"; fail=$((fail + 1)); continue
  fi
  if diff -u "$dir/expected.txt" "$build/stdout.txt" > "$build/diff.txt"; then
    echo "ok   $name ($(wc -l < "$dir/expected.txt" | tr -d ' ') lines)"
    pass=$((pass + 1))
  else
    echo "FAIL $name: output differs from expected.txt"; head -n 40 "$build/diff.txt"; fail=$((fail + 1))
  fi
done

echo "$pass passed, $fail failed, $skip skipped"
[ "$fail" -eq 0 ]
