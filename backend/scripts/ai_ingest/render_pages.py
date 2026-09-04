#!/usr/bin/env python3
"""Render every page of a scanned PDF to a PNG, one file per page.

Thin wrapper around `pdftoppm` (poppler-utils) — no Python PDF library needed.
Output naming matches what ocr_batch.py expects: {stem}-{page:04d}.png, 1-indexed,
in a per-book subdirectory so a corpus-wide run doesn't collide filenames across books.

Usage:
    python3 render_pages.py "path/to/book.pdf" --out pages/ [--dpi 150] [--start 1] [--end N]
"""
from __future__ import annotations  # `int | None` below needs this on Python < 3.10

import argparse
import subprocess
import sys
from pathlib import Path


def page_count(pdf_path: Path) -> int:
    out = subprocess.run(["pdfinfo", str(pdf_path)], capture_output=True, text=True)
    for line in out.stdout.splitlines():
        if line.startswith("Pages:"):
            return int(line.split(":")[1].strip())
    raise RuntimeError(f"could not read page count for {pdf_path}")


def render(pdf_path: Path, out_dir: Path, dpi: int, start: int | None, end: int | None) -> Path:
    """Renders into out_dir/<book-stem>/<book-stem>-0001.png etc. Returns the book subdir."""
    book_dir = out_dir / pdf_path.stem
    book_dir.mkdir(parents=True, exist_ok=True)

    total = page_count(pdf_path)
    first = start or 1
    last = end or total

    cmd = [
        "pdftoppm", "-f", str(first), "-l", str(last), "-r", str(dpi), "-png",
        "-progress",
        str(pdf_path), str(book_dir / pdf_path.stem),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"pdftoppm failed on {pdf_path}: {result.stderr}")

    rendered = sorted(book_dir.glob(f"{pdf_path.stem}-*.png"))
    print(f"{pdf_path.name}: rendered {len(rendered)}/{last - first + 1} pages "
          f"(book has {total} total) -> {book_dir}", file=sys.stderr)
    return book_dir


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pdf", type=Path)
    parser.add_argument("--out", type=Path, default=Path("pages"))
    parser.add_argument("--dpi", type=int, default=150, help="150 was sufficient in the manual pilot")
    parser.add_argument("--start", type=int, default=None)
    parser.add_argument("--end", type=int, default=None)
    args = parser.parse_args()
    render(args.pdf, args.out, args.dpi, args.start, args.end)
