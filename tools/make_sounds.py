"""Synthesise Memory Card's sound palette into app/assets/sounds/*.wav (pure Python, no downloads).

    python tools/make_sounds.py

Soft, short and papery: the study loop plays these hundreds of times a day, so nothing is loud or long
(audit: 4-5 short clicks and one fanfare). 44.1 kHz, mono, 16-bit.
"""
import math
import pathlib
import random
import struct
import wave

RATE = 44100
OUT = pathlib.Path(__file__).resolve().parents[1] / "app" / "assets" / "sounds"
rng = random.Random(47)


def silence(sec):
    return [0.0] * int(RATE * sec)


def env(n, attack=0.004, decay=6.0):
    """Fast attack, exponential decay (decay = how many e-folds over the sound)."""
    a = max(1, int(RATE * attack))
    out = []
    for i in range(n):
        if i < a:
            out.append(i / a)
        else:
            out.append(math.exp(-decay * (i - a) / max(1, n - a)))
    return out


def tone(freq, sec, vol=0.5, decay=6.0, attack=0.004, glide_to=None, partials=((1, 1.0),)):
    n = int(RATE * sec)
    e = env(n, attack, decay)
    out = []
    phase = [0.0] * len(partials)
    for i in range(n):
        f = freq if glide_to is None else freq * (glide_to / freq) ** (i / n)
        s = 0.0
        for k, (mult, amp) in enumerate(partials):
            phase[k] += 2 * math.pi * f * mult / RATE
            s += amp * math.sin(phase[k])
        out.append(vol * e[i] * s)
    return out


def noise(sec, vol=0.3, decay=8.0, attack=0.002, low=0.0, high=1.0):
    """Band-limited noise: one-pole low-pass at `high`, minus a low-pass at `low` (0..1 of Nyquist-ish)."""
    n = int(RATE * sec)
    e = env(n, attack, decay)
    lp1 = lp2 = 0.0
    out = []
    for i in range(n):
        x = rng.uniform(-1, 1)
        lp1 += high * (x - lp1)
        lp2 += low * (x - lp2)
        out.append(vol * e[i] * (lp1 - lp2))
    return out


def mix(*tracks, offsets=None):
    offsets = offsets or [0.0] * len(tracks)
    length = max(int(RATE * o) + len(t) for t, o in zip(tracks, offsets))
    out = [0.0] * length
    for t, o in zip(tracks, offsets):
        start = int(RATE * o)
        for i, v in enumerate(t):
            out[start + i] += v
    return out


def marimba(freq, sec=0.35, vol=0.4):
    # Wooden bar: fundamental plus the 4th and 10th partials, fast decay of the overtones.
    a = tone(freq, sec, vol, decay=7.0, attack=0.002)
    b = tone(freq * 3.93, sec * 0.4, vol * 0.18, decay=10.0, attack=0.001)
    c = tone(freq * 9.2, sec * 0.15, vol * 0.06, decay=14.0, attack=0.001)
    return mix(a, b, c)


def bell(freq, sec=1.2, vol=0.3):
    return mix(
        tone(freq, sec, vol, decay=4.5, attack=0.003),
        tone(freq * 2.76, sec * 0.6, vol * 0.25, decay=6.0, attack=0.002),
        tone(freq * 5.4, sec * 0.3, vol * 0.1, decay=8.0, attack=0.001),
    )


def write(name, samples, gain=0.9):
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = gain / peak if peak > gain else 1.0
    # Short fade-out so nothing clicks at the end.
    fade = min(len(samples), int(RATE * 0.006))
    for i in range(fade):
        samples[-1 - i] *= i / fade
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))
    print(f"{name}.wav  {len(samples) / RATE * 1000:.0f} ms")


def main():
    # The 60 % commit line locks in: a tiny dry click.
    write("tick", mix(tone(2100, 0.028, 0.35, decay=9), noise(0.012, 0.25, decay=6, high=0.9, low=0.3)), 0.5)
    # Reveal: a paper flick.
    write("flip", mix(noise(0.06, 0.45, decay=7, low=0.08, high=0.55), tone(760, 0.07, 0.18, decay=7, glide_to=1050)), 0.6)
    # Remembered: two wooden notes going up (E5 → B5).
    write("good", mix(marimba(659.25, 0.28, 0.45), marimba(987.77, 0.34, 0.4), offsets=[0, 0.065]), 0.7)
    # Easy: three quick notes up (E5 G#5 B5).
    write("easy", mix(marimba(659.25, 0.22, 0.38), marimba(830.61, 0.24, 0.36), marimba(987.77, 0.36, 0.4),
                      offsets=[0, 0.05, 0.1]), 0.7)
    # Missed: a soft low "thup" (it is not a punishment).
    write("again", mix(tone(230, 0.17, 0.6, decay=5.5, glide_to=118), noise(0.05, 0.12, decay=6, high=0.12)), 0.6)
    # Pills and badges popping.
    write("pop", tone(520, 0.075, 0.5, decay=6, glide_to=820), 0.5)
    # The wax seal lands.
    write("stamp", mix(tone(92, 0.16, 0.9, decay=5, attack=0.001, glide_to=62),
                       noise(0.09, 0.45, decay=7, low=0.02, high=0.35)), 0.85)
    # Sheets and the drawer.
    write("whoosh", noise(0.2, 0.35, decay=3.5, attack=0.05, low=0.01, high=0.12), 0.35)
    # Undo: a short chirp back down.
    write("undo", tone(980, 0.09, 0.4, decay=5, glide_to=620), 0.45)
    # Daily goal: C5 E5 G5 C6 arpeggio, then a soft bell chord.
    arp = mix(marimba(523.25, 0.4, 0.4), marimba(659.25, 0.4, 0.4), marimba(783.99, 0.45, 0.4), marimba(1046.5, 0.6, 0.42),
              offsets=[0, 0.09, 0.18, 0.27])
    chord = mix(bell(523.25, 1.3, 0.16), bell(659.25, 1.3, 0.14), bell(783.99, 1.3, 0.13), bell(1318.5, 1.1, 0.07))
    write("fanfare", mix(arp, chord, offsets=[0, 0.36]), 0.8)
    # A seal (achievement): two bells a fifth apart.
    write("seal", mix(bell(783.99, 1.0, 0.25), bell(1174.66, 0.9, 0.18), offsets=[0, 0.08]), 0.7)


if __name__ == "__main__":
    main()
