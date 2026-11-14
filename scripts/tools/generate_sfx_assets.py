#!/usr/bin/env python3
"""
CROWNFALL: THE LAST LIGHT — Procedural 16-bit PCM .wav SFX Generator (Priority 6)
Uses Python standard library only (wave, struct, math, random).
Outputs 6 .wav files into assets/audio/:
- sfx_coin.wav
- sfx_build.wav
- sfx_hit.wav
- sfx_bow.wav
- sfx_sunset.wav
- sfx_night.wav
"""
import math
import os
import random
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 22050


def resolve_repo_root() -> Path:
    colab_root = Path("/content/drive/MyDrive/crownfall")
    if colab_root.exists():
        return colab_root
    if "__file__" in globals():
        for cand in [Path(__file__).resolve().parent, Path(__file__).resolve().parents[2]]:
            if (cand / "project.godot").exists():
                return cand
    return Path(os.getcwd()).resolve()


def write_wav(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for s in samples:
            clamped = max(-1.0, min(1.0, s))
            frames.extend(struct.pack("<h", int(clamped * 32767.0)))
        wf.writeframes(bytes(frames))


def gen_tone(duration: float, freq_start: float, freq_end: float, amp: float = 0.4, noise: float = 0.0, wave_type: str = "sine") -> list[float]:
    n = int(SAMPLE_RATE * duration)
    out: list[float] = []
    phase = 0.0
    rng = random.Random(42)
    for i in range(n):
        t = i / max(1, n - 1)
        freq = freq_start + (freq_end - freq_start) * t
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        env = (1.0 - t) ** 1.6
        if wave_type == "square":
            val = 1.0 if math.sin(phase) >= 0.0 else -1.0
        elif wave_type == "tri":
            val = 2.0 * abs(2.0 * ((phase / (2.0 * math.pi)) % 1.0) - 1.0) - 1.0
        else:
            val = math.sin(phase)
        if noise > 0.0:
            val = val * (1.0 - noise) + (rng.uniform(-1.0, 1.0) * noise)
        out.append(val * env * amp)
    return out


def main() -> None:
    audio_dir = resolve_repo_root() / "assets" / "audio"
    coin = gen_tone(0.08, 880.0, 880.0, 0.32, 0.0, "tri") + gen_tone(0.14, 1318.5, 1318.5, 0.35, 0.0, "tri")
    build = gen_tone(0.11, 190.0, 75.0, 0.45, 0.35, "square")
    hit = gen_tone(0.14, 150.0, 48.0, 0.50, 0.45, "square")
    bow = gen_tone(0.12, 460.0, 210.0, 0.34, 0.15, "tri")
    sunset = gen_tone(0.45, 330.0, 262.0, 0.30, 0.0, "sine")
    night = gen_tone(0.55, 196.0, 146.8, 0.34, 0.05, "tri")

    outputs = {
        "sfx_coin.wav": coin,
        "sfx_build.wav": build,
        "sfx_hit.wav": hit,
        "sfx_bow.wav": bow,
        "sfx_sunset.wav": sunset,
        "sfx_night.wav": night,
    }
    for fname, samples in outputs.items():
        write_wav(audio_dir / fname, samples)
        print(f"Generated: assets/audio/{fname} ({len(samples)} samples)")


if __name__ == "__main__":
    main()
