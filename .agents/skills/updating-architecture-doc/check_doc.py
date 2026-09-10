#!/usr/bin/env python3
"""Sprawdza, czy docs/architecture/data-flow.html nadąża za kodem.

Użycie (z katalogu głównego repo):
    python3 .agents/skills/updating-architecture-doc/check_doc.py [ścieżka/do/data-flow.html]

Błędy (kod wyjścia 1):
  - plik .gd/.tscn z repo (bez addons/ i test/) nie występuje w dokumencie,
  - sygnał zadeklarowany w kodzie nie występuje w sekcji #sygnaly,
  - autoload z project.godot nie występuje w dokumencie,
  - ścieżka .gd/.tscn wymieniona w dokumencie nie istnieje w repo,
  - pigułka sygnału w diagramie nie odpowiada żadnemu sygnałowi w kodzie,
  - niedozwolona treść w bloku Mermaid (classDef, ; # & albo < inne niż <br/>),
  - krawędź Mermaid prowadząca do/z identyfikatora subgrafu.
Informacje (bez błędu): „Stan na” kontra HEAD i obecność tego hasha w historii.
"""
import re
import subprocess
import sys
from pathlib import Path

DOC_DEFAULT = "docs/architecture/data-flow.html"
CODE_DIRS = ("scenes", "scripts", "tools")
BUILTIN_SIGNALS = {"timeout", "pressed", "resized", "size_changed", "gui_input", "request_completed"}


def sh(*args: str) -> str:
    return subprocess.run(args, capture_output=True, text=True, check=False).stdout.strip()


def main() -> int:
    root = Path(sh("git", "rev-parse", "--show-toplevel") or ".")
    doc_path = Path(sys.argv[1]) if len(sys.argv) > 1 else root / DOC_DEFAULT
    # Komentarze HTML (np. instrukcja na górze pliku) nie są treścią dokumentu.
    doc = re.sub(r"<!--.*?-->", "", doc_path.read_text(encoding="utf-8"), flags=re.S)
    errors: list[str] = []
    infos: list[str] = []

    tracked = [p for p in sh("git", "-C", str(root), "ls-files", "*.gd", "*.tscn").splitlines()
               if not p.startswith(("addons/", "test/"))]
    untracked = [p for p in sh("git", "-C", str(root), "ls-files", "--others", "--exclude-standard",
                               "*.gd", "*.tscn").splitlines()
                 if not p.startswith(("addons/", "test/"))]
    code_files = sorted(set(tracked + untracked))
    all_tracked = sh("git", "-C", str(root), "ls-files").splitlines() + untracked
    basenames = {Path(p).name for p in all_tracked}

    # 1. każdy plik kodu jest wymieniony
    for p in code_files:
        if Path(p).name not in doc:
            errors.append(f"Plik nieopisany w dokumencie: {p}")

    # 2. każda wymieniona ścieżka istnieje
    for token in sorted(set(re.findall(r"(?<![\w/*.-])[\w.-]+(?:/[\w.-]+)*\.(?:gd|tscn)\b",
                                       doc.replace("res://", "")))):
        if "/" in token:
            if not (root / token).exists():
                errors.append(f"Dokument wymienia nieistniejący plik: {token}")
        elif token not in basenames and not token.startswith("."):
            errors.append(f"Dokument wymienia plik, którego nie ma w repo: {token}")

    # 3. sygnały z kodu są w sekcji #sygnaly
    m = re.search(r'<section id="sygnaly">(.*?)</section>', doc, re.S)
    signals_section = m.group(1) if m else ""
    code_signals: dict[str, str] = {}
    for d in CODE_DIRS:
        for f in (root / d).rglob("*.gd"):
            for name in re.findall(r"^signal\s+(\w+)", f.read_text(encoding="utf-8"), re.M):
                code_signals.setdefault(name, str(f.relative_to(root)))
    for name, where in sorted(code_signals.items()):
        if name not in signals_section:
            errors.append(f"Sygnał {name} ({where}) nie występuje w sekcji #sygnaly")

    # 4. pigułki sygnałów w diagramie odpowiadają sygnałom w kodzie
    for name in sorted(set(re.findall(r'\(\["(\w+)', signals_section))):
        if name not in code_signals and name not in BUILTIN_SIGNALS:
            errors.append(f"Diagram sygnałów pokazuje {name}, którego nie ma w kodzie")

    # 5. autoloady
    proj = (root / "project.godot").read_text(encoding="utf-8")
    auto = re.search(r"\[autoload\](.*?)(?:\n\[|\Z)", proj, re.S)
    for name in re.findall(r"^(\w+)=", auto.group(1) if auto else "", re.M):
        if name not in doc:
            errors.append(f"Autoload {name} nie występuje w dokumencie")

    # 6. lint bloków Mermaid
    for i, block in enumerate(re.findall(r'<pre class="mermaid">(.*?)</pre>', doc, re.S), start=1):
        subgraphs = set(re.findall(r"^\s*subgraph\s+(\w+)", block, re.M))
        for ln, line in enumerate(block.splitlines(), start=1):
            where = f"diagram {i}, linia {ln}: {line.strip()[:70]}"
            if "classDef" in line:
                errors.append(f"classDef w diagramie (kolory są w CLASSDEFS w skrypcie) — {where}")
            if re.search(r"[;#&]", line):
                errors.append(f"Znak ; # albo & psuje parser Mermaid — {where}")
            if re.search(r"<(?!br/>)", line):
                errors.append(f"Znak < (poza <br/>) psuje HTML/Mermaid — {where}")
            if re.search(r"(-->|==>|-\.->|---|~~~)", line):
                ends = re.split(r"\s*(?:-->|==>|-\.->|---|~~~)(?:\|[^|]*\|)?\s*", line.strip())
                for end in ends:
                    node_id = re.match(r"(\w+)", end)
                    if node_id and node_id.group(1) in subgraphs:
                        errors.append(f"Krawędź do/z subgrafu {node_id.group(1)} rozbija układ — {where}")

    # 7. stan na / historia
    head = sh("git", "-C", str(root), "rev-parse", "--short", "HEAD")
    stan = re.search(r"Stan na: <b>(\w+)</b>", doc)
    stan_hash = stan.group(1) if stan else "?"
    infos.append(f"„Stan na” w nagłówku: {stan_hash}; HEAD repo: {head}")
    if stan and stan_hash not in re.search(r'<section id="historia">(.*?)</section>', doc, re.S).group(1):
        errors.append(f"Hash {stan_hash} z nagłówka nie ma wiersza w sekcji #historia")

    for line in infos:
        print(f"INFO  {line}")
    for line in errors:
        print(f"BŁĄD  {line}")
    print(f"\n{len(errors)} błędów, {len(code_files)} plików kodu, {len(code_signals)} sygnałów sprawdzonych.")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
