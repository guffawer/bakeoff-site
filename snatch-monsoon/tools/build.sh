#!/bin/sh
# Exports the web build to looks/snatch/monsoon/ and adds the loading screen (the still frame,
# a progress bar and a line of text) to Godot's default page.
#   GODOT=/path/to/Godot tools/build.sh
set -eu
cd "$(dirname "$0")/.."
GODOT="${GODOT:-../../tools/Godot.app/Contents/MacOS/Godot}"
OUT="$(cd ../looks/snatch/monsoon && pwd)"
mkdir -p build
"$GODOT" --headless --path . --import > build/import.log 2>&1
"$GODOT" --headless --path . --export-release Web "$OUT/index.html" > build/web.log 2>&1
if grep -n -E "^(SCRIPT )?ERROR" build/import.log build/web.log; then echo "Export reported errors." >&2; exit 1; fi
python3 -I tools/loading_screen.py "$OUT/index.html"
ls -l "$OUT"
