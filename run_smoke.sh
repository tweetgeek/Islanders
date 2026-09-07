#!/bin/sh
# Headless smoke test scen: ładuje Main przez tools/Smoke.tscn i sprawdza przepływ mapa -> detal -> mapa.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")"
tmp="$(mktemp)"
"$GODOT" --headless --path . res://tools/Smoke.tscn >"$tmp" 2>&1
status=$?
grep -E "^(OK|FAIL|SMOKE)|SCRIPT ERROR|ERROR:" "$tmp"
rm -f "$tmp"
exit "$status"
