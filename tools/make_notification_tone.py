#!/usr/bin/env python3
"""Synthesises the app's notification tone.

Committed as a script rather than only its output so the tone is reproducible
and adjustable — and so it is obvious the audio was generated here, not taken
from somewhere with a rights holder. A real adhan recording is a licensing
decision for the owner; this is a neutral placeholder that is unambiguously ours.

Two soft struck tones a perfect fifth apart, each with an exponential decay so
they read as a bell rather than a beep. Deliberately quiet and short: a prayer
reminder should be noticeable without being startling.

    python3 tools/make_notification_tone.py out.wav
"""
import math
import struct
import sys
import wave

RATE = 44100
NOTES = [(880.0, 0.00), (1318.5, 0.28)]   # A5, then E6 — a fifth above
DURATION = 1.6
DECAY = 4.2
PEAK = 0.32                                # headroom; notification tones clip easily


def sample(t: float) -> float:
    value = 0.0
    for freq, start in NOTES:
        if t < start:
            continue
        age = t - start
        envelope = math.exp(-DECAY * age)
        # A touch of the second harmonic gives the strike some body.
        value += envelope * (
            math.sin(2 * math.pi * freq * age)
            + 0.28 * math.sin(4 * math.pi * freq * age)
        )
    return value


def main(path: str) -> None:
    frames = int(RATE * DURATION)
    raw = [sample(i / RATE) for i in range(frames)]
    peak = max(abs(v) for v in raw) or 1.0
    scale = (PEAK * 32767) / peak

    # Fade the last 80ms so the tail cannot click.
    fade = int(0.08 * RATE)
    with wave.open(path, "w") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        data = bytearray()
        for i, v in enumerate(raw):
            gain = min(1.0, (frames - i) / fade) if i > frames - fade else 1.0
            data += struct.pack("<h", int(max(-32768, min(32767, v * scale * gain))))
        out.writeframes(bytes(data))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "tone.wav")
