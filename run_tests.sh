#!/bin/sh
# Uruchamia testy gdUnit4 headless. Użycie: ./run_tests.sh [ścieżka, domyślnie test/]
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
cd "$(dirname "$0")"
"$GODOT" --headless --path . --import >/dev/null 2>&1
"$GODOT" --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --add "${1:-test/}"
