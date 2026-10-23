#!/bin/sh
# Builds every demo listed in demos.txt into site/<name>/ and writes the
# gallery at site/index.html. Usage: ./build.sh [site-dir]   (KAI=path/to/kai)
set -eu

KAI="${KAI:-kai}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
SITE="${1:-$ROOT/site}"

escape() {
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' "$@"
}

title_of() {
  sed -n '1s/^# *//p' "$1/README.md"
}

blurb_of() {
  sed -n '2,$p' "$1/README.md" | sed '/^$/d' | head -n 1
}

source_block() {
  printf '<pre class="source"><code>'
  escape "$1/main.kai"
  printf '</code></pre>\n'
}

# A demo's own page.html, with its `<!-- source -->` line replaced by the source.
custom_page() {
  dir="$1"
  source_block "$dir" > "$SITE/.source.html"
  awk -v src="$SITE/.source.html" '
    /^<!-- source -->$/ { while ((getline line < src) > 0) print line; next }
    { print }
  ' "$dir/page.html"
  rm -f "$SITE/.source.html"
}

demo_page() {
  dir="$1"
  name="$2"
  title="$(title_of "$dir" | escape)"
  blurb="$(blurb_of "$dir" | escape)"
  cat <<PAGE
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title · kaikai on WebAssembly</title>
<link rel="stylesheet" href="../style.css">
</head>
<body>
<main>
<a class="back" href="../">← all demos</a>
<header>
<h1>$title</h1>
<p>$blurb</p>
</header>
<section>
<h2>Output</h2>
<pre id="kai-stdout" class="output"></pre>
</section>
<section>
<h2>Source · $name/main.kai</h2>
$(source_block "$dir")
</section>
<footer>Compiled from kaikai to WebAssembly with <code>kai build --target=wasm32-browser</code>.</footer>
</main>
<script type="module" src="app.mjs"></script>
</body>
</html>
PAGE
}

card() {
  dir="$1"
  name="$2"
  if [ -f "$dir/thumb.png" ]; then
    preview="<img class=\"thumb\" src=\"$name/thumb.png\" alt=\"\" loading=\"lazy\">"
  else
    peek=""
    if [ -f "$dir/expected.txt" ]; then
      peek="$(head -n 14 "$dir/expected.txt" | escape)"
    fi
    preview="<pre class=\"peek\">$peek</pre>"
  fi
  cat <<CARD
<a class="card" href="$name/">
$preview
<div class="body">
<h2>$(title_of "$dir" | escape)</h2>
<p>$(blurb_of "$dir" | escape)</p>
</div>
</a>
CARD
}

mkdir -p "$SITE"
cp "$ROOT/web/style.css" "$SITE/style.css"

canvas_cards=""
console_cards=""
section=console
while read -r name; do
  case "$name" in
    "" | "#"*) continue ;;
    "[canvas]") section=canvas; continue ;;
    "[console]") section=console; continue ;;
  esac
  dir="$ROOT/demos/$name"
  echo "build $name"
  mkdir -p "$SITE/$name"
  "$KAI" build --target=wasm32-browser "$dir/main.kai" -o "$SITE/$name/app" < /dev/null
  if [ -f "$dir/page.html" ]; then
    custom_page "$dir" > "$SITE/$name/index.html"
  else
    demo_page "$dir" "$name" > "$SITE/$name/index.html"
  fi
  if [ -f "$dir/thumb.png" ]; then
    cp "$dir/thumb.png" "$SITE/$name/thumb.png"
  fi
  if [ "$section" = canvas ]; then
    canvas_cards="$canvas_cards$(card "$dir" "$name")
"
  else
    console_cards="$console_cards$(card "$dir" "$name")
"
  fi
done < "$ROOT/demos.txt"

cat > "$SITE/index.html" <<EOF
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>kaikai on WebAssembly</title>
<link rel="stylesheet" href="style.css">
</head>
<body>
<main>
<header>
<h1>kaikai on WebAssembly</h1>
<p>Small kaikai programs compiled to WebAssembly and run in your browser.</p>
</header>
<h2 class="section">On the page</h2>
<p class="intro">Games, canvases and widgets that draw on the page and listen to it: keys, clicks and timer ticks arrive as values from <code>Dom.next_event</code>, through the effects <code>web.run</code> installs, or through <code>extern "js"</code>.</p>
<div class="gallery">
$canvas_cards</div>
<h2 class="section">Console</h2>
<p class="intro">Programs that compute and print; what they write to <code>Stdout</code> lands on the page.</p>
<div class="gallery">
$console_cards</div>
<footer>Built with <code>kai build --target=wasm32-browser</code>. The pages that wait for events or sleep need JSPI: Chrome/Edge 137, Firefox 153, Safari 27.</footer>
</main>
</body>
</html>
EOF

echo "site written to $SITE"
