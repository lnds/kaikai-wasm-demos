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

demo_page() {
  dir="$1"
  name="$2"
  title="$(title_of "$dir" | escape)"
  blurb="$(blurb_of "$dir" | escape)"
  cat <<EOF
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
<pre class="source"><code>$(escape "$dir/main.kai")</code></pre>
</section>
<footer>Compiled from kaikai to WebAssembly with <code>kai build --target=wasm32-browser</code>.</footer>
</main>
<script type="module" src="app.mjs"></script>
</body>
</html>
EOF
}

card() {
  dir="$1"
  name="$2"
  peek=""
  if [ -f "$dir/expected.txt" ]; then
    peek="$(head -n 14 "$dir/expected.txt" | escape)"
  fi
  cat <<EOF
<a class="card" href="$name/">
<pre class="peek">$peek</pre>
<div class="body">
<h2>$(title_of "$dir" | escape)</h2>
<p>$(blurb_of "$dir" | escape)</p>
</div>
</a>
EOF
}

mkdir -p "$SITE"
cp "$ROOT/web/style.css" "$SITE/style.css"

cards=""
for name in $(grep -v '^#' "$ROOT/demos.txt"); do
  dir="$ROOT/demos/$name"
  echo "build $name"
  mkdir -p "$SITE/$name"
  "$KAI" build --target=wasm32-browser "$dir/main.kai" -o "$SITE/$name/app"
  if [ -f "$dir/page.html" ]; then
    cp "$dir/page.html" "$SITE/$name/index.html"
  else
    demo_page "$dir" "$name" > "$SITE/$name/index.html"
  fi
  cards="$cards$(card "$dir" "$name")
"
done

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
<p>Small kaikai programs compiled to WebAssembly and run in your browser. Each one prints to the page.</p>
</header>
<div class="gallery">
$cards</div>
<footer>Built with <code>kai build --target=wasm32-browser</code>. Interactive demos arrive with DOM support.</footer>
</main>
</body>
</html>
EOF

echo "site written to $SITE"
