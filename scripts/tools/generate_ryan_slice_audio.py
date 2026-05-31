#!/usr/bin/env python3
"""Generate short replaceable Ryan-slice placeholder WAV files."""

from __future__ import annotations

import math
import random
import wave
from pathlib import Path

RATE = 22050
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "audio" / "placeholders"

EVENTS = {
    "drop": (0.09, 210.0, "tap"),
    "collision": (0.07, 150.0, "tap"),
    "ingredient_drop": (0.13, 280.0, "fall"),
    "barrel_shake": (0.22, 105.0, "noise"),
    "grill_sizzle": (0.24, 420.0, "noise"),
    "pot_stir": (0.20, 170.0, "noise"),
    "product_ready": (0.24, 660.0, "chime"),
    "serve_success": (0.28, 760.0, "chime"),
    "serve_fail": (0.24, 190.0, "fall"),
    "page_turn": (0.16, 330.0, "noise"),
    "new_document": (0.32, 540.0, "chime"),
    "wash_complete": (0.30, 240.0, "fall"),
}


def sample(kind: str, frequency: float, t: float, duration: float) -> float:
    envelope = max(0.0, 1.0 - t / duration)
    tone = math.sin(2.0 * math.pi * frequency * t)
    if kind == "noise":
        return (0.58 * random.uniform(-1.0, 1.0) + 0.22 * tone) * envelope
    if kind == "fall":
        falling = math.sin(2.0 * math.pi * frequency * (1.0 - 0.55 * t / duration) * t)
        return falling * envelope
    if kind == "chime":
        overtone = math.sin(2.0 * math.pi * frequency * 1.5 * t)
        return (0.68 * tone + 0.25 * overtone) * envelope
    return tone * envelope


def write_wav(name: str, duration: float, frequency: float, kind: str) -> None:
    frames = bytearray()
    rng = random.Random(name)
    random.seed(rng.random())
    for index in range(int(RATE * duration)):
        t = index / RATE
        value = max(-1.0, min(1.0, sample(kind, frequency, t, duration)))
        pcm = int(value * 11000)
        frames.extend(pcm.to_bytes(2, "little", signed=True))
    with wave.open(str(OUT / f"{name}.wav"), "wb") as target:
        target.setnchannels(1)
        target.setsampwidth(2)
        target.setframerate(RATE)
        target.writeframes(frames)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, (duration, frequency, kind) in EVENTS.items():
        write_wav(name, duration, frequency, kind)
        print(f"[audio] {name}.wav")


if __name__ == "__main__":
    main()
