"""Generates the game's short sound effects as 16-bit mono WAV files.

Run from the project root:  python3 tools/gen_audio.py
"""
import math
import os
import random
import struct
import wave

SAMPLE_RATE = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "audio")


def write_wav(name, samples):
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name)
    frames = bytearray()
    for sample in samples:
        clamped = max(-1.0, min(1.0, sample))
        frames += struct.pack("<h", int(clamped * 32000))
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(bytes(frames))
    print("wrote", path, len(samples) / SAMPLE_RATE, "s")


def flap():
    duration = 0.1
    count = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    rng = random.Random(11)
    for i in range(count):
        t = i / SAMPLE_RATE
        progress = t / duration
        freq = 420.0 + 620.0 * progress
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        envelope = min(1.0, t / 0.004) * (1.0 - progress) ** 1.7
        tone = 0.45 * math.sin(phase) + 0.16 * math.sin(phase * 2.0)
        air = 0.18 * (rng.random() * 2.0 - 1.0)
        samples.append((tone + air) * envelope * 0.8)
    return samples


def score():
    duration = 0.19
    count = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    for i in range(count):
        t = i / SAMPLE_RATE
        if t < 0.07:
            freq = 988.0
            local = t
            envelope = (1.0 - local / 0.07) ** 1.2
        else:
            freq = 1319.0
            local = t - 0.07
            envelope = (1.0 - local / 0.12) ** 1.4
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        tone = 0.55 * math.sin(phase) + 0.2 * math.sin(phase * 2.0) + 0.08 * math.sin(phase * 3.0)
        samples.append(tone * envelope * 0.55)
    return samples


def hit():
    duration = 0.14
    count = int(SAMPLE_RATE * duration)
    rng = random.Random(5)
    samples = []
    phase = 0.0
    for i in range(count):
        t = i / SAMPLE_RATE
        progress = t / duration
        freq = 190.0 * (1.0 - progress * 0.45)
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        envelope = (1.0 - progress) ** 1.5
        noise = (rng.random() * 2.0 - 1.0) * 0.5
        samples.append((0.5 * math.sin(phase) + noise) * envelope * 0.9)
    return samples


def die():
    duration = 0.5
    count = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    for i in range(count):
        t = i / SAMPLE_RATE
        progress = t / duration
        freq = 520.0 * (1.0 - progress) ** 1.6 + 90.0
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        envelope = (1.0 - progress) ** 1.1 * min(1.0, t / 0.01)
        tone = 0.4 * math.sin(phase) + 0.18 * math.sin(phase * 3.0) + 0.1 * math.sin(phase * 5.0)
        samples.append(tone * envelope * 0.7)
    return samples


if __name__ == "__main__":
    write_wav("flap.wav", flap())
    write_wav("score.wav", score())
    write_wav("hit.wav", hit())
    write_wav("die.wav", die())
