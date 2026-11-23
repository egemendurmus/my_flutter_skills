#!/usr/bin/env python3
"""Flutter projesinde tekrar eden widget bloklarını ve UI kod kokularını bulur.

Kullanım:
    python3 find_widget_duplicates.py lib/ [--min-similarity 0.8] [--min-lines 5] [--json]

Sadece aday gösterir; hangi tekrarın gerçekten ortak bileşen olacağına
insan / Claude karar verir. Ek paket gerektirmez.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from difflib import SequenceMatcher
from pathlib import Path

GENERATED_SUFFIXES = (".g.dart", ".freezed.dart", ".gr.dart", ".config.dart", ".mocks.dart")

# Ortak bileşen adayı sayılacak kök widget'lar (bir bloğu başlatan çağrılar).
ROOT_WIDGETS = {
    "Container", "Card", "Row", "Column", "Padding", "DecoratedBox", "ListTile",
    "InkWell", "GestureDetector", "Stack", "SizedBox", "Material", "ClipRRect",
    "ElevatedButton", "FilledButton", "OutlinedButton", "TextButton", "TextField",
    "TextFormField", "Chip", "AppBar", "Wrap",
}

STRING_RE = re.compile(r"'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\"")
NUMBER_RE = re.compile(r"\b\d+(?:\.\d+)?\b")
IDENT_RE = re.compile(r"\b[a-z_][A-Za-z0-9_]*\b")
COMMENT_RE = re.compile(r"//[^\n]*|/\*.*?\*/", re.S)

BUILD_METHOD_RE = re.compile(r"^\s*Widget\s+(_build\w*)\s*\(", re.M)
HARDCODED_COLOR_RE = re.compile(r"\bColor\(0x[0-9A-Fa-f]{8}\)|\bColors\.(?!transparent\b)\w+")
HARDCODED_INSETS_RE = re.compile(r"EdgeInsets\.\w+\(\s*[^)]*\b\d+(?:\.\d+)?")
HARDCODED_FONT_RE = re.compile(r"fontSize\s*:\s*\d+")


@dataclass
class Block:
    file: str
    line: int
    root: str
    lines: int
    raw: str
    normalized: str


@dataclass
class FileStats:
    file: str
    lines: int
    build_methods: list[tuple[str, int]] = field(default_factory=list)
    colors: int = 0
    insets: int = 0
    fonts: int = 0


def is_generated(path: Path) -> bool:
    return path.name.endswith(GENERATED_SUFFIXES)


def matching_paren(src: str, open_idx: int) -> int:
    """`(` konumundan eşleşen `)` konumunu döner; string içlerini atlar."""
    depth = 0
    i = open_idx
    n = len(src)
    while i < n:
        ch = src[i]
        if ch in "'\"":
            quote = ch
            i += 1
            while i < n and src[i] != quote:
                i += 2 if src[i] == "\\" else 1
        elif ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def normalize(code: str) -> str:
    """Değişken adları, metinler ve sayılar farklı olsa da yapıyı karşılaştırılabilir yapar."""
    code = COMMENT_RE.sub("", code)
    code = STRING_RE.sub("S", code)
    code = NUMBER_RE.sub("N", code)
    # Küçük harfle başlayan tanımlayıcılar (değişken/parametre) → v
    # Named argüman adları (ör. `padding:`) yapının parçası olduğu için korunur.
    code = IDENT_RE.sub(lambda m: m.group(0) if code[m.end():m.end() + 1] == ":" else "v", code)
    return re.sub(r"\s+", "", code)


def extract_blocks(path: Path, src: str, min_lines: int) -> list[Block]:
    blocks: list[Block] = []
    pattern = re.compile(r"\b(?:const\s+)?(" + "|".join(sorted(ROOT_WIDGETS)) + r")(?:\.\w+)?\s*\(")
    for m in pattern.finditer(src):
        open_idx = src.index("(", m.start(1))
        close_idx = matching_paren(src, open_idx)
        if close_idx == -1:
            continue
        raw = src[m.start(1):close_idx + 1]
        n_lines = raw.count("\n") + 1
        if n_lines < min_lines:
            continue
        blocks.append(Block(
            file=str(path),
            line=src.count("\n", 0, m.start(1)) + 1,
            root=m.group(1),
            lines=n_lines,
            raw=raw,
            normalized=normalize(raw),
        ))
    return blocks


def contains(outer: Block, inner: Block) -> bool:
    return (
        outer.file == inner.file
        and outer.line <= inner.line
        and inner.line + inner.lines <= outer.line + outer.lines
        and outer is not inner
    )


def drop_covered_groups(groups: list[list[tuple[Block, float]]]) -> list[list[tuple[Block, float]]]:
    """Tüm üyeleri daha önce raporlanmış bir grubun bloklarının içinde kalan grupları at.

    Böylece iç içe tekrarlar (ör. kartın içindeki rozet) ayrıca raporlanır,
    ama sadece büyük tekrarın parçası olduklarında gürültü yapmaz.
    """
    accepted: list[list[tuple[Block, float]]] = []
    reported: list[Block] = []
    for g in groups:
        if all(any(contains(r, b) for r in reported) for b, _ in g):
            continue
        accepted.append(g)
        reported.extend(b for b, _ in g)
    return accepted


def group_similar(blocks: list[Block], threshold: float) -> list[list[tuple[Block, float]]]:
    blocks = sorted(blocks, key=lambda b: -b.lines)
    groups: list[list[tuple[Block, float]]] = []
    used: set[int] = set()
    for i, a in enumerate(blocks):
        if i in used:
            continue
        group = [(a, 1.0)]
        for j in range(i + 1, len(blocks)):
            if j in used:
                continue
            b = blocks[j]
            if a.root != b.root:
                continue
            la, lb = len(a.normalized), len(b.normalized)
            if min(la, lb) / max(la, lb) < threshold:
                continue  # boyut çok farklı: hızlı ele
            ratio = SequenceMatcher(None, a.normalized, b.normalized, autojunk=False).ratio()
            if ratio >= threshold:
                group.append((b, ratio))
                used.add(j)
        if len(group) > 1:
            used.add(i)
            groups.append(group)
    # Önce büyük bloklar (iç içe filtre için), raporda ise kalabalık gruplar üstte.
    groups.sort(key=lambda g: -g[0][0].lines)
    return groups


def scan(root: Path, min_lines: int, max_file_lines: int) -> tuple[list[Block], list[FileStats]]:
    blocks: list[Block] = []
    stats: list[FileStats] = []
    files = [root] if root.is_file() else sorted(root.rglob("*.dart"))
    for path in files:
        if is_generated(path):
            continue
        src = path.read_text(encoding="utf-8", errors="replace")
        st = FileStats(file=str(path), lines=src.count("\n") + 1)
        st.build_methods = [
            (m.group(1), src.count("\n", 0, m.start()) + 1) for m in BUILD_METHOD_RE.finditer(src)
        ]
        is_theme_file = "theme" in path.parts or "constants" in path.parts
        if not is_theme_file:
            st.colors = len(HARDCODED_COLOR_RE.findall(src))
            st.insets = len(HARDCODED_INSETS_RE.findall(src))
            st.fonts = len(HARDCODED_FONT_RE.findall(src))
        stats.append(st)
        blocks.extend(extract_blocks(path, src, min_lines))
    return blocks, stats


def main() -> int:
    # Windows konsolu (cp1252) Türkçe karakterde UnicodeEncodeError verir.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("path", type=Path, help="Taranacak klasör (genelde lib/)")
    parser.add_argument("--min-similarity", type=float, default=0.8)
    parser.add_argument("--min-lines", type=int, default=5)
    parser.add_argument("--max-file-lines", type=int, default=300)
    parser.add_argument("--json", action="store_true", help="Makine okunur çıktı")
    args = parser.parse_args()

    if not args.path.exists():
        print(f"Bulunamadı: {args.path}", file=sys.stderr)
        return 2

    blocks, stats = scan(args.path, args.min_lines, args.max_file_lines)
    groups = drop_covered_groups(group_similar(blocks, args.min_similarity))
    groups.sort(key=lambda g: (-len(g), -sum(b.lines for b, _ in g)))
    long_files = [s for s in stats if s.lines > args.max_file_lines]
    build_methods = [s for s in stats if s.build_methods]
    hardcoded = [s for s in stats if s.colors or s.insets or s.fonts]

    if args.json:
        print(json.dumps({
            "duplicate_groups": [
                [{"file": b.file, "line": b.line, "root": b.root, "lines": b.lines, "similarity": round(r, 2)}
                 for b, r in g] for g in groups
            ],
            "long_files": [{"file": s.file, "lines": s.lines} for s in long_files],
            "build_methods": [{"file": s.file, "methods": s.build_methods} for s in build_methods],
            "hardcoded": [{"file": s.file, "colors": s.colors, "insets": s.insets, "fonts": s.fonts}
                          for s in hardcoded],
        }, ensure_ascii=False, indent=2))
        return 0

    print(f"Taranan dosya: {len(stats)}  |  Aday blok: {len(blocks)}\n")

    print(f"== Benzer widget grupları ({len(groups)}) ==")
    for i, g in enumerate(groups, 1):
        total = sum(b.lines for b, _ in g)
        print(f"\n[{i}] {g[0][0].root} — {len(g)} yerde, toplam ~{total} satır")
        for b, r in g:
            print(f"    {b.file}:{b.line}  ({b.lines} satır, benzerlik {r:.0%})")
    if not groups:
        print("  yok")

    print(f"\n== Widget döndüren _build metotları ({sum(len(s.build_methods) for s in build_methods)}) ==")
    for s in build_methods:
        for name, line in s.build_methods:
            print(f"    {s.file}:{line}  {name}()")
    if not build_methods:
        print("  yok")

    print(f"\n== {args.max_file_lines} satırı aşan dosyalar ({len(long_files)}) ==")
    for s in sorted(long_files, key=lambda s: -s.lines):
        print(f"    {s.file}  {s.lines} satır")
    if not long_files:
        print("  yok")

    print(f"\n== Gömülü değerler (tema/constants hariç) ==")
    for s in sorted(hardcoded, key=lambda s: -(s.colors + s.insets + s.fonts)):
        print(f"    {s.file}  renk:{s.colors}  padding:{s.insets}  fontSize:{s.fonts}")
    if not hardcoded:
        print("  yok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
