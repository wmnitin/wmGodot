#!/usr/bin/env python3
"""Synthesize the Capy Tower Wars soundtrack. No third-party samples.

Writes 16-bit mono WAV files into assets/audio. Re-run this script to
rebuild them. The sounds are dedicated to the public domain (CC0).
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

SR = 22050
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
OUT.mkdir(parents=True, exist_ok=True)

# C major pentatonic, cheerful and hard to make dissonant.
NOTE = {
    "C3": 130.81, "D3": 146.83, "E3": 164.81, "G3": 196.00, "A3": 220.00,
    "C4": 261.63, "D4": 293.66, "E4": 329.63, "G4": 392.00, "A4": 440.00,
    "C5": 523.25, "D5": 587.33, "E5": 659.25, "G5": 783.99, "A5": 880.00,
    "C6": 1046.50,
}


def silence(seconds: float) -> list[float]:
    return [0.0] * int(SR * seconds)


def _shape(phase: float, kind: str) -> float:
    if kind == "sine":
        return math.sin(phase * math.tau)
    if kind == "triangle":
        p = phase % 1.0
        return 4.0 * p - 1.0 if p < 0.5 else 3.0 - 4.0 * p
    if kind == "soft":
        # Sine plus a quiet second harmonic. Warmer than a bare beep.
        return math.sin(phase * math.tau) * 0.85 + math.sin(phase * math.tau * 2.0) * 0.15
    return math.sin(phase * math.tau)


def tone(freq: float, seconds: float, volume: float = 0.3, kind: str = "soft", attack: float = 0.01, release: float = 0.08) -> list[float]:
    n = max(1, int(SR * seconds))
    attack_n = max(1, int(SR * attack))
    release_n = max(1, int(SR * release))
    out = [0.0] * n
    phase = 0.0
    step = freq / SR
    for i in range(n):
        env = 1.0
        if i < attack_n:
            env = i / attack_n
        tail = n - i
        if tail < release_n:
            env *= tail / release_n
        out[i] = _shape(phase, kind) * volume * env
        phase += step
    return out


def noise(seconds: float, volume: float = 0.2, seed: int = 1) -> list[float]:
    rng = random.Random(seed)
    n = max(1, int(SR * seconds))
    release_n = max(1, int(n * 0.55))
    out = []
    prev = 0.0
    for i in range(n):
        sample = rng.uniform(-1.0, 1.0)
        prev = prev * 0.82 + sample * 0.18  # dull the hiss
        env = 1.0 if i > n - release_n else 1.0
        tail = n - i
        if tail < release_n:
            env = tail / release_n
        attack = min(1.0, i / max(1, int(SR * 0.008)))
        out.append(prev * volume * env * attack)
    return out


def mix(tracks: list[list[float]], peak: float = 0.9) -> list[float]:
    length = max(len(track) for track in tracks)
    mixed = [0.0] * length
    for track in tracks:
        for i, sample in enumerate(track):
            mixed[i] += sample
    loudest = max(1e-6, max(abs(sample) for sample in mixed))
    scale = peak / loudest
    return [max(-1.0, min(1.0, sample * scale)) for sample in mixed]


def add(base: list[float], extra: list[float], at: float) -> None:
    start = int(SR * at)
    for i, sample in enumerate(extra):
        index = start + i
        if index >= len(base):
            base.append(0.0)
        base[index] += sample


def save(name: str, samples: list[float]) -> None:
    path = OUT / name
    with wave.open(str(path), "w") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        frames = bytearray()
        for sample in samples:
            frames += struct.pack("<h", int(max(-1.0, min(1.0, sample)) * 32767))
        handle.writeframes(frames)
    print(path.relative_to(path.parents[2]))


def blip(start: float, end: float, seconds: float, volume: float) -> list[float]:
    n = max(1, int(SR * seconds))
    out = []
    phase = 0.0
    for i in range(n):
        t = i / max(1, n - 1)
        freq = start + (end - start) * t
        env = math.sin(t * math.pi)
        out.append(_shape(phase, "soft") * volume * env)
        phase += freq / SR
    return out


def make_music() -> list[float]:
    beat = 60.0 / 128.0
    bars = 8
    total = beat * 4 * bars
    bed = silence(total)
    # Left-hand bounce on the beat.
    bass_pattern = ["C3", "G3", "C3", "A3"] * bars
    for index, name in enumerate(bass_pattern):
        add(bed, tone(NOTE[name], beat * 0.92, 0.22, "triangle", 0.01, 0.06), index * beat)
    # A small repeating tune. It starts and ends on C so the loop joins.
    melody = [
        "E5", "G5", "A5", "G5",
        "E5", "D5", "C5", "D5",
        "E5", "G5", "C6", "A5",
        "G5", "E5", "D5", "C5",
    ]
    for index, name in enumerate(melody):
        add(bed, tone(NOTE[name], beat * 0.8, 0.18, "soft", 0.012, 0.08), index * beat)
    # Quiet off-beat ticks, like a toy drum.
    tick = noise(0.04, 0.08, seed=4)
    step = beat / 2.0
    when = step
    while when < total - 0.05:
        add(bed, tick, when)
        when += beat
    # Fade the join so the loop does not click.
    fade = int(SR * 0.02)
    for i in range(fade):
        bed[i] *= i / fade
        bed[-1 - i] *= i / fade
    return mix([bed], peak=0.86)


def make_spawn() -> list[float]:
    return mix([blip(620, 1180, 0.09, 0.5)], peak=0.8)


def make_clash() -> list[float]:
    return mix([
        noise(0.16, 0.55, seed=9),
        tone(180, 0.14, 0.4, "triangle", 0.005, 0.08),
        tone(90, 0.18, 0.25, "sine", 0.005, 0.1),
    ], peak=0.85)


def make_capture() -> list[float]:
    notes = ["C5", "E5", "G5", "C6"]
    bed = silence(0.7)
    for index, name in enumerate(notes):
        add(bed, tone(NOTE[name], 0.22, 0.4, "soft", 0.008, 0.1), index * 0.09)
    return mix([bed], peak=0.88)


def make_level_up() -> list[float]:
    notes = ["G4", "B4", "D5", "G5"]
    # B4 is not in the table. Use the frequency directly.
    freqs = [392.00, 493.88, 587.33, 783.99]
    bed = silence(0.62)
    for index, freq in enumerate(freqs):
        add(bed, tone(freq, 0.18, 0.38, "soft", 0.006, 0.08), index * 0.07)
    return mix([bed], peak=0.86)


def make_win() -> list[float]:
    freqs = [261.63, 329.63, 392.00, 523.25, 659.25, 783.99, 1046.50]
    bed = silence(1.35)
    for index, freq in enumerate(freqs):
        add(bed, tone(freq, 0.28, 0.34, "soft", 0.008, 0.12), index * 0.11)
    add(bed, tone(523.25, 0.55, 0.16, "triangle", 0.02, 0.2), 0.7)
    return mix([bed], peak=0.88)


def make_lose() -> list[float]:
    freqs = [440.00, 349.23, 293.66, 220.00]
    bed = silence(1.15)
    for index, freq in enumerate(freqs):
        add(bed, tone(freq, 0.32, 0.36, "triangle", 0.01, 0.14), index * 0.16)
    return mix([bed], peak=0.8)


def make_ui() -> list[float]:
    return mix([blip(700, 980, 0.06, 0.45)], peak=0.7)


def make_cut() -> list[float]:
    return mix([
        noise(0.07, 0.35, seed=2),
        blip(500, 220, 0.08, 0.25),
    ], peak=0.75)


def make_connect() -> list[float]:
    return mix([blip(420, 760, 0.11, 0.5)], peak=0.8)


def main() -> None:
    save("music.wav", make_music())
    save("spawn.wav", make_spawn())
    save("clash.wav", make_clash())
    save("capture.wav", make_capture())
    save("level_up.wav", make_level_up())
    save("win.wav", make_win())
    save("lose.wav", make_lose())
    save("ui.wav", make_ui())
    save("cut.wav", make_cut())
    save("connect.wav", make_connect())


if __name__ == "__main__":
    main()
