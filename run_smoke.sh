#!/bin/sh
# Headless smoke test scen: ładuje Main przez tools/Smoke.tscn i sprawdza przepływ osada -> mapa -> arkusze -> osada.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT INT TERM HUP
"$GODOT" --headless --path . res://tools/Smoke.tscn >"$tmp" 2>&1
status=$?
grep -E "^(OK|FAIL|SMOKE)|SCRIPT ERROR|ERROR:" "$tmp"
if [ "$status" -eq 0 ] && grep -qE "SCRIPT ERROR|ERROR:" "$tmp"; then
	status=1
fi
exit "$status"
