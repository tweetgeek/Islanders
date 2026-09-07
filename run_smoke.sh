#!/bin/sh
# Headless smoke test scen: ładuje Main przez tools/Smoke.tscn i sprawdza przepływ mapa -> detal -> mapa.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")"
"$GODOT" --headless --path . res://tools/Smoke.tscn 2>&1 | grep -E "^(OK|FAIL|SMOKE)|SCRIPT ERROR|ERROR:"
