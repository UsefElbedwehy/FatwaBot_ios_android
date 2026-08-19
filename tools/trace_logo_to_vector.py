#!/usr/bin/env python3
"""Traces the logo PNG into an Android vector drawable.

Android notification icons must be a flat silhouette with an alpha channel — the
system paints them a single colour and discards everything else. The two
drawables this replaces were hand-approximated blobs (a rounded arch and a
generic star), not the mark.

Rather than eyeball a path, this follows the actual pixels: threshold to a mask,
trace every region boundary, simplify, and emit one evenOdd path. evenOdd is what
makes the logo's counters (the inner arch and lantern openings) render as holes
instead of filled slabs.

    python3 tools/trace_logo_to_vector.py logo.png out.xml --size 24 --check
"""
import argparse
import sys

import numpy as np
from PIL import Image

# 8-neighbour offsets, clockwise from east — Moore-neighbourhood tracing order.
NEIGHBOURS = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]


def load_mask(path: str, threshold: int = 160) -> np.ndarray:
    """True where the artwork has ink."""
    img = Image.open(path).convert("RGBA")
    arr = np.array(img)
    alpha = arr[..., 3]
    lum = arr[..., :3].mean(axis=2)
    # Ink = opaque and dark. The source is maroon on white (or on transparency).
    return (alpha > 128) & (lum < threshold)


def trace_boundary(mask: np.ndarray, start: tuple[int, int]) -> list[tuple[int, int]]:
    """Moore-neighbourhood border following from `start`, returning a closed loop."""
    h, w = mask.shape
    contour = [start]
    cur = start
    # Enter from the west, so the first probe sweeps around correctly.
    backtrack = 4
    guard = 0
    while guard < 4 * mask.size:
        guard += 1
        found = False
        for step in range(1, 9):
            idx = (backtrack + step) % 8
            dx, dy = NEIGHBOURS[idx]
            nx, ny = cur[0] + dx, cur[1] + dy
            if 0 <= nx < w and 0 <= ny < h and mask[ny, nx]:
                # Came from the opposite side of the new pixel.
                backtrack = (idx + 4) % 8
                cur = (nx, ny)
                contour.append(cur)
                found = True
                break
        if not found:
            break               # isolated pixel
        if cur == start and len(contour) > 2:
            break
    return contour


def components(mask: np.ndarray) -> list[np.ndarray]:
    """Connected components of a boolean mask, each as its own mask."""
    from collections import deque

    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    out = []
    for y in range(h):
        for x in range(w):
            if not mask[y, x] or seen[y, x]:
                continue
            comp = np.zeros_like(mask, dtype=bool)
            q = deque([(x, y)])
            seen[y, x] = True
            while q:
                cx, cy = q.popleft()
                comp[cy, cx] = True
                for dx, dy in NEIGHBOURS:
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < w and 0 <= ny < h and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        q.append((nx, ny))
            out.append(comp)
    return out


def simplify(points: list[tuple[float, float]], tol: float) -> list[tuple[float, float]]:
    """Douglas–Peucker. Keeps corners, drops the pixel staircase between them."""
    if len(points) < 3:
        return points
    start, end = points[0], points[-1]
    dx, dy = end[0] - start[0], end[1] - start[1]
    norm = (dx * dx + dy * dy) ** 0.5
    worst, index = 0.0, 0
    for i in range(1, len(points) - 1):
        px, py = points[i]
        if norm == 0:
            d = ((px - start[0]) ** 2 + (py - start[1]) ** 2) ** 0.5
        else:
            d = abs(dy * px - dx * py + end[0] * start[1] - end[1] * start[0]) / norm
        if d > worst:
            worst, index = d, i
    if worst <= tol:
        return [start, end]
    left = simplify(points[: index + 1], tol)
    right = simplify(points[index:], tol)
    return left[:-1] + right


def contours(mask: np.ndarray, tol: float) -> list[list[tuple[float, float]]]:
    """Outer boundary of every ink region, plus the boundary of every enclosed hole."""
    loops = []
    for comp in components(mask):
        ys, xs = np.nonzero(comp)
        start = (int(xs[np.argmin(ys)]), int(ys.min()))
        loops.append(trace_boundary(comp, start))

        # Holes: background regions inside this component that never touch the edge.
        padded = np.pad(~comp, 1, constant_values=True)
        for bg in components(padded):
            if bg[0, :].any() or bg[-1, :].any() or bg[:, 0].any() or bg[:, -1].any():
                continue                      # connected to the outside
            inner = bg[1:-1, 1:-1]
            if not inner.any():
                continue
            ys, xs = np.nonzero(inner)
            loops.append(trace_boundary(inner, (int(xs[np.argmin(ys)]), int(ys.min()))))

    return [simplify([(float(x), float(y)) for x, y in loop], tol) for loop in loops]


def to_path_data(loops, scale, ox, oy) -> str:
    parts = []
    for loop in loops:
        if len(loop) < 3:
            continue
        pts = [(round((x - ox) * scale, 2), round((y - oy) * scale, 2)) for x, y in loop]
        parts.append("M" + f"{pts[0][0]},{pts[0][1]}"
                     + "".join(f" L{x},{y}" for x, y in pts[1:]) + " Z")
    return " ".join(parts)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("png")
    ap.add_argument("out")
    ap.add_argument("--size", type=float, default=24.0)
    ap.add_argument("--colour", default="#FFFFFFFF")
    ap.add_argument("--tolerance", type=float, default=0.9)
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    mask = load_mask(args.png)
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        print("no ink found", file=sys.stderr)
        return 1
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    span = max(x1 - x0, y1 - y0) + 1
    scale = args.size / span
    # Centre the mark inside the square viewport.
    ox = x0 - (span - (x1 - x0 + 1)) / 2
    oy = y0 - (span - (y1 - y0 + 1)) / 2

    loops = contours(mask, args.tolerance)
    data = to_path_data(loops, scale, ox, oy)

    with open(args.out, "w") as fh:
        fh.write(
            f'<?xml version="1.0" encoding="utf-8"?>\n'
            f'<!-- Generated by tools/trace_logo_to_vector.py from the logo artwork.\n'
            f'     Do not hand-edit: regenerate instead. evenOdd is required so the\n'
            f'     mark\'s inner counters stay open rather than filling solid. -->\n'
            f'<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
            f'    android:width="{args.size:g}dp" android:height="{args.size:g}dp"\n'
            f'    android:viewportWidth="{args.size:g}" android:viewportHeight="{args.size:g}">\n'
            f'  <path android:fillColor="{args.colour}"\n'
            f'        android:fillType="evenOdd"\n'
            f'        android:pathData="{data}"/>\n'
            f'</vector>\n'
        )

    print(f"{args.out}: {len(loops)} contour(s), {len(data)} chars of path data")

    if args.check:
        # Rasterise what we emitted and compare to the source mask. A tracer that
        # looks right in the XML and wrong on screen is the failure mode here.
        from PIL import ImageDraw
        size = 512
        k = size / args.size
        got = np.zeros((size, size), dtype=bool)
        for loop in loops:
            poly = [((x - ox) * scale * k, (y - oy) * scale * k) for x, y in loop]
            if len(poly) < 3:
                continue
            layer = Image.new("1", (size, size), 0)
            ImageDraw.Draw(layer).polygon(poly, fill=1, outline=1)
            # XOR is exactly what evenOdd does: a loop inside another subtracts.
            got ^= np.array(layer, dtype=bool)

        ref = Image.fromarray((mask * 255).astype(np.uint8)).crop(
            (int(ox), int(oy), int(ox + span), int(oy + span))
        ).resize((size, size), Image.NEAREST)
        ref = np.array(ref) > 127
        inter = (got & ref).sum()
        union = (got | ref).sum()
        print(f"IoU vs source (evenOdd): {inter / union:.3f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
