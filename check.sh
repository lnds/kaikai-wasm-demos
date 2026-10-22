#!/bin/sh
# Builds each demo in demos.txt for wasm32-browser, runs it under node and
# diffs the output against demos/<name>/expected.txt, the output of `kai run`
# on the host. A demo without expected.txt is only built.
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
  set -- $(grep -v '^#' "$ROOT/demos.txt")
fi

run_node() {
  if node "$1/kai_host.mjs" "$1/app.wasm" > "$1/stdout.txt" 2> "$1/stderr.txt"; then
    return 0
  fi
  # Older node releases ship WebAssembly exception handling behind a flag.
  if grep -q exnref "$1/stderr.txt"; then
    node --experimental-wasm-exnref "$1/kai_host.mjs" "$1/app.wasm" > "$1/stdout.txt" 2> "$1/stderr.txt"
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
