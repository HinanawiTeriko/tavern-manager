#!/usr/bin/env python3
"""Generate the minimum identifiable Ryan-slice placeholder PNG pack."""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEXTURES = ROOT / "assets" / "textures"


def rgba(color: tuple[int, int, int], alpha: int = 255) -> tuple[int, int, int, int]:
    return color + (alpha,)


def write_png(path: Path, width: int, height: int, pixels) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rows = bytearray()
    for y in range(height):
        rows.append(0)
        for x in range(width):
            rows.extend(bytes(pixels(x, y)))

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    payload = b"\x89PNG\r\n\x1a\n"
    payload += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    payload += chunk(b"IDAT", zlib.compress(bytes(rows), 9))
    payload += chunk(b"IEND", b"")
    path.write_bytes(payload)
    print(f"[png] {path.relative_to(ROOT)}")


def tavern_pixel(x: int, y: int) -> tuple[int, int, int, int]:
    if y < 390:
        return rgba((35 + y // 25, 27 + y // 35, 24))
    if y < 650:
        return rgba((88, 57, 34) if (x // 48 + y // 24) % 2 else (99, 64, 38))
    return rgba((43, 31, 23))


def portrait_pixel(mood: str):
    moods = {
        "neutral": ((74, 103, 128), 0),
        "excited": ((110, 84, 145), -7),
        "hesitant": ((91, 111, 100), 7),
        "dejected": ((70, 76, 92), 14),
    }
    cloth, mouth_curve = moods[mood]

    def pixel(x: int, y: int) -> tuple[int, int, int, int]:
        if (x - 128) ** 2 + (y - 135) ** 2 < 76 ** 2:
            color = (222, 174, 126)
            if (x - 102) ** 2 + (y - 122) ** 2 < 7 ** 2 or (x - 154) ** 2 + (y - 122) ** 2 < 7 ** 2:
                color = (38, 30, 28)
            expected_y = 170 + mouth_curve - abs(x - 128) // 5 if mouth_curve <= 0 else 164 + abs(x - 128) // 5
            if 104 <= x <= 152 and abs(y - expected_y) <= 2:
                color = (92, 42, 42)
            return rgba(color)
        if 52 <= x <= 204 and y >= 205:
            return rgba(cloth)
        if 92 <= x <= 164 and 46 <= y <= 75:
            return rgba((115, 76, 42))
        return rgba((0, 0, 0), 0)

    return pixel


def icon_pixel(base: tuple[int, int, int], mark: tuple[int, int, int], style: str):
    def pixel(x: int, y: int) -> tuple[int, int, int, int]:
        if not (4 <= x < 60 and 4 <= y < 60):
            return rgba((0, 0, 0), 0)
        if style == "powder" and (x - 32) ** 2 + (y - 32) ** 2 < 18 ** 2:
            return rgba(mark)
        if style == "blood" and (x + y) % 17 < 5:
            return rgba(mark)
        if style == "contract" and 14 <= x <= 50 and 12 <= y <= 52 and (x % 9 == 0 or y % 11 == 0):
            return rgba(mark)
        return rgba(base)

    return pixel


def vfx_pixel(base: tuple[int, int, int], style: str):
    def pixel(x: int, y: int) -> tuple[int, int, int, int]:
        dx, dy = x - 32, y - 32
        radius = dx * dx + dy * dy
        if style == "burst" and (abs(dx) <= 3 or abs(dy) <= 3 or abs(abs(dx) - abs(dy)) <= 2) and radius < 850:
            return rgba(base, 220)
        if style == "ring" and 250 < radius < 500:
            return rgba(base, 200)
        if style == "drop" and dx * dx + (dy - 8) * (dy - 8) < 230:
            return rgba(base, 210)
        return rgba((0, 0, 0), 0)

    return pixel


def main() -> None:
    write_png(TEXTURES / "backgrounds" / "tavern_bg.png", 1280, 720, tavern_pixel)
    for mood in ["neutral", "excited", "hesitant", "dejected"]:
        write_png(TEXTURES / "characters" / f"ryan_{mood}.png", 256, 320, portrait_pixel(mood))

    write_png(TEXTURES / "icons" / "items" / "sleep_powder.png", 64, 64,
              icon_pixel((89, 64, 126), (201, 176, 240), "powder"))
    write_png(TEXTURES / "icons" / "items" / "bloodied_contract.png", 64, 64,
              icon_pixel((186, 158, 109), (133, 25, 25), "blood"))
    write_png(TEXTURES / "icons" / "items" / "alternative_contract.png", 64, 64,
              icon_pixel((199, 176, 121), (76, 111, 65), "contract"))

    write_png(TEXTURES / "vfx" / "ingredient_drop.png", 64, 64, vfx_pixel((119, 176, 232), "drop"))
    write_png(TEXTURES / "vfx" / "product_ready.png", 64, 64, vfx_pixel((255, 207, 91), "burst"))
    write_png(TEXTURES / "vfx" / "serve_success.png", 64, 64, vfx_pixel((119, 214, 107), "burst"))
    write_png(TEXTURES / "vfx" / "new_document.png", 64, 64, vfx_pixel((237, 186, 99), "ring"))


if __name__ == "__main__":
    main()
