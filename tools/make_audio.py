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


def brass(freq: float, seconds: float, volume: float = 0.3) -> list[float]:
    """A few stacked harmonics, closer to a bugle than a toy beep."""
    n = max(1, int(SR * seconds))
    attack_n = max(1, int(SR * 0.03))
    release_n = max(1, int(SR * 0.09))
    weights = (1.0, 0.62, 0.34, 0.16, 0.07)
    phases = [0.0] * len(weights)
    out = []
    for i in range(n):
        env = 1.0
        if i < attack_n:
            env = i / attack_n
        tail = n - i
        if tail < release_n:
            env *= tail / release_n
        sample = 0.0
        for index, weight in enumerate(weights):
            sample += math.sin(phases[index] * math.tau) * weight
            phases[index] += freq * (index + 1) / SR
        out.append(sample * volume * env)
    return out


def bass_drum(volume: float = 0.7) -> list[float]:
    n = int(SR * 0.22)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        freq = 90.0 * math.exp(-t * 14.0) + 42.0
        env = math.exp(-t * 10.0)
        phase += freq / SR
        click = math.exp(-t * 80.0) * 0.35
        out.append((math.sin(phase * math.tau) * 0.9 + click) * volume * env)
    return out


def snare(volume: float = 0.45, seconds: float = 0.12, seed: int = 3) -> list[float]:
    rng = random.Random(seed)
    n = max(1, int(SR * seconds))
    out = []
    prev = 0.0
    phase = 0.0
    for i in range(n):
        t = i / SR
        raw = rng.uniform(-1.0, 1.0)
        prev = prev * 0.35 + raw * 0.65
        env = math.exp(-t * 22.0)
        phase += 190.0 / SR
        tone_part = math.sin(phase * math.tau) * math.exp(-t * 30.0) * 0.35
        out.append((prev * 0.75 + tone_part) * volume * env)
    return out


def make_music() -> list[float]:
    # A short march: bass drum on 1 and 3, snare on 2 and 4, brass lead.
    # 112 bpm, eight bars, starts and ends on D so the loop can join.
    beat = 60.0 / 112.0
    bars = 8
    total = beat * 4 * bars
    bed = silence(total + 0.05)
    kick = bass_drum(0.85)
    snare_hit = snare(0.55, 0.11, seed=6)
    for bar in range(bars):
        bar_at = bar * beat * 4
        add(bed, kick, bar_at)
        add(bed, kick, bar_at + beat * 2)
        add(bed, snare_hit, bar_at + beat)
        add(bed, snare_hit, bar_at + beat * 3)
    # A snare roll into the downbeat so the loop feels like a march, not a fade-out.
    roll = snare(0.28, 0.045, seed=8)
    roll_start = total - beat
    step = beat / 8.0
    when = roll_start
    while when < total - 0.02:
        add(bed, roll, when)
        when += step
    melody = [
        293.66, 293.66, 349.23, 440.00,
        587.33, 440.00, 349.23, 329.63,
        293.66, 349.23, 440.00, 587.33,
        440.00, 349.23, 329.63, 293.66,
    ]
    for index, freq in enumerate(melody):
        add(bed, brass(freq, beat * 1.7, 0.22), index * beat * 2)
    # Quiet octave under the lead, so the brass has a body.
    for index, freq in enumerate(melody):
        if index % 2 == 0:
            add(bed, brass(freq * 0.5, beat * 3.2, 0.08), index * beat * 2)
    fade = int(SR * 0.012)
    for i in range(fade):
        bed[i] *= i / fade
        bed[-1 - i] *= i / fade
    return mix([bed], peak=0.9)


def make_spawn() -> list[float]:
    return mix([blip(620, 1180, 0.09, 0.5)], peak=0.8)


def make_clash() -> list[float]:
    # A short metal ping plus a body hit. Louder and brighter than a thud.
    return mix([
        noise(0.07, 0.85, seed=11),
        tone(1680, 0.09, 0.42, "sine", 0.001, 0.04),
        tone(2460, 0.06, 0.22, "sine", 0.001, 0.03),
        tone(210, 0.12, 0.5, "triangle", 0.002, 0.05),
    ], peak=0.92)


def make_tank_shot() -> list[float]:
    return mix([
        noise(0.2, 0.9, seed=3),
        tone(70, 0.28, 0.7, "sine", 0.002, 0.14),
        tone(48, 0.34, 0.45, "sine", 0.002, 0.16),
        blip(280, 60, 0.18, 0.4),
    ], peak=0.93)


def make_tank_rumble() -> list[float]:
    seconds = 1.0
    n = int(SR * seconds)
    rng = random.Random(5)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        phase += 36.0 / SR
        low = math.sin(phase * math.tau) * 0.55 + math.sin(phase * math.tau * 2.0) * 0.18
        hiss = rng.uniform(-1.0, 1.0) * 0.1
        local = (t % 0.14) / 0.14
        bump = math.exp(-local * 7.0)
        out.append((low + hiss) * (0.5 + 0.5 * bump))
    fade = int(SR * 0.02)
    for i in range(fade):
        out[i] *= i / fade
        out[-1 - i] *= i / fade
    return mix([out], peak=0.8)


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
    save("tank_shot.wav", make_tank_shot())
    save("tank_rumble.wav", make_tank_rumble())


if __name__ == "__main__":
    main()
