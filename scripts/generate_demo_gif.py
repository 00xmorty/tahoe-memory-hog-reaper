#!/usr/bin/env python3
"""Generate the README terminal demo GIF.

The terminal body is rendered into a clipped viewport first, then pasted into the
outer frame. This prevents command animation from overflowing outside the
terminal chrome as lines accumulate.
"""

from __future__ import annotations

from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "demo.gif"

W, H = 960, 560
PANEL = (54, 48, W - 54, H - 48)
BODY = (80, 114, W - 80, H - 72)  # clipped terminal viewport
LINE_H = 20
FONT_SIZE = 16
MAX_LINES = (BODY[3] - BODY[1]) // LINE_H

BG = (10, 14, 22)
PANEL_BG = (18, 24, 38)
TITLE_BG = (25, 34, 52)
BORDER = (62, 75, 99)
TEXT = (221, 229, 239)
DIM = (148, 163, 184)
GREEN = (52, 211, 153)
CYAN = (34, 211, 238)
YELLOW = (250, 204, 21)
RED = (248, 113, 113)
PURPLE = (168, 85, 247)

SCRIPT_LINES = [
    ("$ tahoe-memory-hog-reaper status", GREEN),
    ("Memory pressure:", CYAN),
    ("  System pressure: normal     swap used: 0.00M", TEXT),
    ("  No panic. No sudo. No daemon.", DIM),
    ("", TEXT),
    ("Top memory processes:", CYAN),
    ("  PID     RSS_GB  CPU%   COMMAND", DIM),
    ("  1481    1.57    8.9    Virtualization.framework", TEXT),
    ("  1364    0.30    0.0    Comet", TEXT),
    ("  31899   0.22    3.5    hermes", TEXT),
    ("", TEXT),
    ("$ tahoe-memory-hog-reaper scan --threshold-gb 1", GREEN),
    ("Candidates above 1GB RSS:", CYAN),
    ("  PID     RSS_GB  PROTECTED  COMMAND", DIM),
    ("  1481    1.57    no         Virtualization.framework", YELLOW),
    ("", TEXT),
    ("$ tahoe-memory-hog-reaper reap --interactive --threshold-gb 1", GREEN),
    ("Dry-run safety: no signal will be sent.", RED),
    ("Add --confirm + type exact PID before TERM.", PURPLE),
    ("✓ Diagnostic-first. You stay in control.", GREEN),
]


def load_font() -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    font_paths = [
        "/System/Library/Fonts/Menlo.ttc",
        "/System/Library/Fonts/Monaco.ttf",
        "/System/Library/Fonts/SFNSMono.ttf",
        "/Library/Fonts/Menlo.ttc",
    ]
    for font_path in font_paths:
        if Path(font_path).exists():
            return ImageFont.truetype(font_path, FONT_SIZE)
    return ImageFont.load_default()


FONT = load_font()


def draw_frame(visible_lines: Iterable[tuple[str, tuple[int, int, int]]], cursor_on: bool) -> Image.Image:
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)

    # Subtle vertical texture so the GIF does not feel flat.
    for y in range(0, H, 4):
        col = (10, 14 + int(y / H * 8), 22 + int(y / H * 18))
        d.line((0, y, W, y), fill=col)

    x0, y0, x1, y1 = PANEL
    d.rounded_rectangle(PANEL, radius=18, fill=PANEL_BG, outline=BORDER, width=2)
    d.rounded_rectangle((x0, y0, x1, y0 + 44), radius=18, fill=TITLE_BG)
    d.rectangle((x0, y0 + 28, x1, y0 + 44), fill=TITLE_BG)

    for i, c in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
        d.ellipse((x0 + 18 + i * 24, y0 + 16, x0 + 30 + i * 24, y0 + 28), fill=c)

    d.text(
        (x0 + 120, y0 + 14),
        "tahoe-memory-hog-reaper — safe macOS memory diagnostics",
        font=FONT,
        fill=DIM,
    )
    d.rounded_rectangle((x1 - 170, y0 + 11, x1 - 20, y0 + 32), radius=9, fill=(6, 78, 59), outline=GREEN)
    d.text((x1 - 158, y0 + 13), "DRY-RUN SAFE", font=FONT, fill=GREEN)

    # Render the terminal body to a separate image and paste only the viewport.
    # This is the bugfix: previous versions drew every line directly on the full
    # frame, so late lines escaped below the rounded terminal panel.
    bx0, by0, bx1, by1 = BODY
    viewport = Image.new("RGB", (bx1 - bx0, by1 - by0), PANEL_BG)
    vd = ImageDraw.Draw(viewport)
    y = 0
    shown = list(visible_lines)[-MAX_LINES:]
    for line, col in shown:
        vd.text((0, y), line, font=FONT, fill=col)
        y += LINE_H

    if cursor_on:
        cursor_y = min(y + 2, viewport.height - 18)
        vd.rectangle((0, cursor_y, 10, cursor_y + 15), fill=GREEN)

    img.paste(viewport, (bx0, by0))

    # Soft viewport boundary + scroll hint when older lines are above the fold.
    if len(list(visible_lines)) > MAX_LINES:
        d.text((bx1 - 102, by0 - 19), "scrolling", font=FONT, fill=DIM)
        d.line((bx0, by0 - 4, bx1, by0 - 4), fill=(30, 41, 59))

    return img


def main() -> None:
    if MAX_LINES < 10:
        raise SystemExit(f"terminal viewport too short: MAX_LINES={MAX_LINES}")

    # Geometry regression: if all lines are visible without scroll, they must fit.
    # If not, scrolling/clipping is mandatory.
    raw_bottom = BODY[1] + len(SCRIPT_LINES) * LINE_H
    assert raw_bottom > BODY[3], "test data no longer exercises overflow path"
    assert BODY[1] + MAX_LINES * LINE_H <= BODY[3], "viewport line math overflows"

    frames: list[Image.Image] = []
    for visible in range(1, len(SCRIPT_LINES) + 1):
        reps = 3 if visible < len(SCRIPT_LINES) else 12
        visible_lines = SCRIPT_LINES[:visible]
        for r in range(reps):
            frames.append(draw_frame(visible_lines, cursor_on=(r % 2 == 0)))

    for _ in range(12):
        frames.append(frames[-1].copy())

    OUT.parent.mkdir(exist_ok=True)
    frames[0].save(OUT, save_all=True, append_images=frames[1:], duration=85, loop=0, optimize=True)
    print(f"wrote {OUT} frames={len(frames)} size={OUT.stat().st_size} max_lines={MAX_LINES}")


if __name__ == "__main__":
    main()
