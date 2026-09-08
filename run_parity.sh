#!/bin/sh
# Regeneruje contract/world-parity.json (kontrakt geografii klient-serwer, ADR 0001).
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")"
"$GODOT" --headless --path . -s tools/world_parity_dump.gd
