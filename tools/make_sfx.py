"""Synthesises the placeholder combat sound effects into assets/audio/sfx/*.wav.

Pure standard library: run `py tools/make_sfx.py`. Replace any file by dropping a WAV/OGG with
the same id into Music/ next to the game (see Music/audio.json); these are only defaults.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "sfx")


def render(name, seconds, voice, seed=1):
    random.seed(seed)
    count = int(RATE * seconds)
    samples = [voice(i / RATE, i / count) for i in range(count)]
    peak = max(1e-6, max(abs(s) for s in samples))
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(b"".join(struct.pack("<h", int(s / peak * 0.9 * 32767)) for s in samples))


def noise():
    return random.uniform(-1, 1)


class Lowpass:
    def __init__(self):
        self.value = 0.0

    def __call__(self, sample, amount):
        self.value += (sample - self.value) * amount
        return self.value


def swoosh(lp=Lowpass()):
    return lambda t, p: lp(noise(), 0.08 + 0.5 * math.sin(math.pi * p)) * math.sin(math.pi * p) ** 1.5


def hit():
    lp = Lowpass()
    return lambda t, p: (math.sin(2 * math.pi * (180 - 120 * p) * t) * (1 - p) ** 3 * 1.2
                         + lp(noise(), 0.6) * (1 - p) ** 8)


def hurt():
    return lambda t, p: (math.sin(2 * math.pi * (420 - 300 * p) * t) + 0.5 * math.sin(2 * math.pi * (630 - 450 * p) * t)) * (1 - p) ** 2


def jump():
    return lambda t, p: math.sin(2 * math.pi * (300 + 500 * p) * t) * (1 - p) ** 2 * 0.6


def dash():
    lp = Lowpass()
    return lambda t, p: lp(noise(), 0.25) * math.sin(math.pi * p) * (1 - p)


def chime(base, rising=True):
    def voice(t, p):
        notes = [base, base * 1.25, base * 1.5, base * 2] if rising else [base * 2, base * 1.5, base * 1.25, base]
        index = min(3, int(p * 4))
        local = p * 4 - index
        return sum(math.sin(2 * math.pi * notes[i] * t) * math.exp(-6 * max(0, p * 4 - i)) for i in range(index + 1)) * (1 - p) ** 0.5 * (0.6 + 0.4 * local)
    return voice


def pogo():
    return lambda t, p: (math.sin(2 * math.pi * (520 + 380 * p) * t) * (1 - p) ** 3 + 0.3 * noise() * (1 - p) ** 12)


def kill():
    lp = Lowpass()
    return lambda t, p: (lp(noise(), 0.35) * (1 - p) ** 2 + math.sin(2 * math.pi * (880 - 600 * p) * t) * 0.5 * (1 - p) ** 4)


def slam():
    lp = Lowpass()
    return lambda t, p: (math.sin(2 * math.pi * (70 - 35 * p) * t) * (1 - p) ** 1.5 + lp(noise(), 0.12) * (1 - p) ** 3)


def windup():
    return lambda t, p: math.sin(2 * math.pi * (140 + 260 * p) * t) * math.sin(math.pi * p) * 0.7


def focus():
    return lambda t, p: (math.sin(2 * math.pi * 330 * t) + 0.5 * math.sin(2 * math.pi * 495 * t)) * math.sin(math.pi * p) * (0.6 + 0.4 * math.sin(2 * math.pi * 7 * t))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    render("slash", 0.16, swoosh(), 2)
    render("hit", 0.18, hit(), 3)
    render("hurt", 0.32, hurt(), 4)
    render("jump", 0.12, jump(), 5)
    render("dash", 0.2, dash(), 6)
    render("heal", 0.7, chime(660), 7)
    render("pickup", 0.4, chime(990), 8)
    render("pogo", 0.16, pogo(), 9)
    render("kill", 0.45, kill(), 10)
    render("slam", 0.6, slam(), 11)
    render("windup", 0.3, windup(), 12)
    render("focus", 0.85, focus(), 13)
    render("victory", 1.2, chime(523), 14)
    render("magic", 0.35, chime(784), 15)
    print("Wrote sound effects to", os.path.abspath(OUT))
