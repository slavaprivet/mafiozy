"""Generate footstep sounds for the castle map, procedurally.

Four surfaces, four voices:
  stone  - a hard click with a short, bright ring: brick and masonry
  wood   - a lower knock with a body resonance: gates, planks, boards
  dirt   - a soft crunch of grit, mid-heavy, no ring
  grass  - the quietest of the four: a brush with no transient at all

No samples are used; everything is synthesised, so the sounds belong to this project and
carry no licence. Each surface gets four variants so a walk does not repeat.
"""
import math
import os
import random
import struct
import wave

RATE = 44100


def envelope(n, attack, decay, curve=2.0):
    """A simple attack/decay envelope, sample by sample."""
    out = []
    for i in range(n):
        t = i / RATE
        a = min(1.0, t / attack) if attack > 0 else 1.0
        d = math.exp(-t / decay) if decay > 0 else 1.0
        out.append(a * (d ** (1.0 / curve)))
    return out


def noise(n, seed):
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def lowpass(samples, cutoff):
    """A one-pole low pass: cheap, and enough to shape grit and grass."""
    alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff / RATE)
    out = []
    last = 0.0
    for s in samples:
        last += alpha * (s - last)
        out.append(last)
    return out


def highpass(samples, cutoff):
    alpha = 1.0 - math.exp(-2.0 * math.pi * cutoff / RATE)
    out = []
    last = 0.0
    prev = 0.0
    for s in samples:
        last += alpha * (s - last)
        out.append(s - last)
        prev = s
    return out


def make_stone(seed):
    n = int(RATE * 0.13)
    env = envelope(n, 0.001, 0.020, 1.6)
    body = noise(n, seed)
    body = highpass(lowpass(body, 5200.0), 420.0)
    click = [math.sin(2.0 * math.pi * 1750.0 * i / RATE) * math.exp(-i / (RATE * 0.006)) for i in range(n)]
    out = []
    for i in range(n):
        out.append((body[i] * 0.55 + click[i] * 0.45) * env[i] * 0.85)
    return out


def make_wood(seed):
    n = int(RATE * 0.19)
    env = envelope(n, 0.002, 0.045, 2.2)
    body = lowpass(noise(n, seed), 1200.0)
    knock = []
    for i in range(n):
        t = i / RATE
        tone = (math.sin(2.0 * math.pi * 196.0 * t) * 0.5
                + math.sin(2.0 * math.pi * 293.0 * t) * 0.3
                + math.sin(2.0 * math.pi * 421.0 * t) * 0.2)
        knock.append(tone * math.exp(-t / 0.035))
    out = []
    for i in range(n):
        out.append((body[i] * 0.35 + knock[i] * 0.65) * env[i] * 0.9)
    return out


def make_dirt(seed):
    n = int(RATE * 0.15)
    env = envelope(n, 0.004, 0.030, 1.4)
    grit = highpass(lowpass(noise(n, seed), 2200.0), 260.0)
    out = []
    for i in range(n):
        out.append(grit[i] * env[i] * 0.7)
    return out


def make_grass(seed):
    n = int(RATE * 0.17)
    env = envelope(n, 0.010, 0.040, 1.2)
    brush = highpass(lowpass(noise(n, seed), 3400.0), 700.0)
    out = []
    for i in range(n):
        out.append(brush[i] * env[i] * 0.42)
    return out


def write_wav(path, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    if peak > 0.98:
        samples = [s / peak * 0.98 for s in samples]
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples)
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(frames)


def main():
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "audio", "steps")
    os.makedirs(out_dir, exist_ok=True)
    makers = {"stone": make_stone, "wood": make_wood, "dirt": make_dirt, "grass": make_grass}
    written = 0
    for name, maker in makers.items():
        for variant in range(1, 5):
            samples = maker(name.__hash__() if False else (hash(name) & 0xFFFF) + variant * 977)
            path = os.path.join(out_dir, "%s_%d.wav" % (name, variant))
            write_wav(path, samples)
            written += 1
    print("steps written:", written, "into", out_dir)


if __name__ == "__main__":
    main()
