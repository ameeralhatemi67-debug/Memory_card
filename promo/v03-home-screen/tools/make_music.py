"""The music bed for Video 3 (108 BPM, C major, plucky), made with the app's own synth voices
(tools/make_sounds.py: marimba, bell), like Video 1's.

    python promo/v03-home-screen/tools/make_music.py

Writes assets/sounds/music.wav (44.1 kHz, mono, 16-bit, 32.0 s). A placeholder bed: swap the file for a
licensed track at 104-112 BPM and keep the <audio id="music"> element.

Form (beats from 0, one beat = 60/108 s), each section on the film's beats (SPEC.md):
  0-2    a plucked C rising as the hand of cards comes up
  3-6    one marimba note per widget landing, climbing E G C E
  7-11   a light C groove under "Widgets that keep you going"
  12-20  Am | F ostinato under the Quick card (Reveal on 15, Got it on 18)
  21-25  a G arpeggio climbing to the stamp
  26-27  the stamp: a held low C and a bell, no percussion
  28-33  C quarter notes under the membership card
  34-43  one chord per tap in Settings: C, Am (blue), F (green), Dm (dark), G (light)
  44-50  the montage: kick on every beat, eighths C | Am | F | G
  51-53  the end card; the final chord on beat 53 (the third logo card), ringing to the end
"""
import math
import pathlib
import struct
import sys
import wave

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parents[1] / "tools"))
import make_sounds as ms  # noqa: E402  (the app's synth: marimba(), bell(), tone(), noise())

RATE = ms.RATE
BEAT = 60 / 108
LENGTH = 32.0
ms.rng.seed(108)
out = [0.0] * int(RATE * LENGTH)


def at(beat, samples, gain=1.0):
    start = int(round(beat * BEAT * RATE))
    for i, v in enumerate(samples):
        j = start + i
        if 0 <= j < len(out):
            out[j] += v * gain


def hz(name):
    notes = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semis = notes[name[0]] + (1 if "#" in name else 0) - (1 if name[1] == "b" else 0)
    return 440.0 * 2 ** ((semis + 12 * (int(name[-1]) - 4)) / 12)


def mallet(name, sec=0.42, vol=0.3):
    return ms.mix(ms.marimba(hz(name), sec, vol), ms.noise(0.012, vol * 0.25, decay=9, low=0.2, high=0.7))


def pluck(name, vol=0.3, sec=0.45):
    """A pizzicato-like pluck: bright attack, quick decay, harmonics so it reads on a phone speaker."""
    return ms.tone(hz(name), sec, vol, decay=8.0, attack=0.002, partials=((1, 1.0), (2, 0.5), (3, 0.28), (4, 0.12)))


def kick(vol=0.2):
    return ms.mix(ms.tone(118, 0.16, vol, decay=6, attack=0.001, glide_to=52), ms.noise(0.01, vol * 0.3, decay=8, low=0.1, high=0.6))


def shaker(vol=0.045):
    return ms.noise(0.05, vol, decay=7, attack=0.004, low=0.45, high=0.95)


def pad(names, beat, beats, vol=0.04):
    for n in names:
        at(beat, ms.tone(hz(n), beats * BEAT + 0.35, vol, decay=1.6, attack=0.18, partials=((1, 1.0), (2, 0.22), (3, 0.06))))


def eighths(start, cell, beats, vol=0.18):
    for k in range(int(beats * 2)):
        at(start + k / 2, mallet(cell[k % len(cell)], 0.36, vol if k % 2 == 0 else vol * 0.75))


C, AM, F, G, DM = ["C4", "E4", "G4"], ["A3", "C4", "E4"], ["F3", "A3", "C4"], ["G3", "B3", "D4"], ["D4", "F4", "A4"]

# 0-2: a plucked C rising with the hand; a low hum under it.
for b, n in [(0, "C3"), (1, "G3"), (2, "C4"), (2.5, "E4")]:
    at(b, pluck(n, 0.26))
at(0, ms.tone(hz("C3"), 3.0, 0.03, decay=1.2, attack=0.4, partials=((1, 1.0), (2, 0.3))))
at(0, ms.noise(LENGTH, 0.01, decay=0.01, attack=0.5, low=0.01, high=0.08))  # room tone

# 3-6: one note per widget landing.
for b, n in [(3, "E4"), (4, "G4"), (5, "C5"), (6, "E5")]:
    at(b, mallet(n, 0.6, 0.3))
    at(b, pluck("C3", 0.2))
pad(C, 3, 4)

# 7-11: a light C groove.
eighths(7, ["C4", "G4", "E4", "G4"], 5, 0.16)
for b in (7, 9, 11):
    at(b, kick(0.18))
at(7, pluck("C3", 0.24))
at(9, pluck("G2", 0.22))
pad(C, 7, 5)

# 12-20: Am | F ostinato under the Quick card.
eighths(12, ["A3", "E4", "C5", "E4"], 4)
eighths(16, ["F3", "C4", "A4", "C4"], 5)
for b in range(12, 21, 2):
    at(b, kick(0.18))
at(12, pluck("A2", 0.26))
at(16, pluck("F2", 0.26))
pad(AM, 12, 4)
pad(F, 16, 5)

# 21-25: a G arpeggio climbing to the stamp.
cells = {21: ["G3", "B3", "D4", "G4"], 22: ["B3", "D4", "G4", "B4"], 23: ["D4", "G4", "B4", "D5"],
         24: ["G4", "B4", "D5", "G5"], 25: ["B4", "D5", "F5", "G5"]}
for b, cell in cells.items():
    for k, n in enumerate(cell):
        at(b + k / 4, mallet(n, 0.3, 0.18 if k == 0 else 0.13))
    at(b, kick(0.2))
    at(b + 0.5, shaker())
at(21, pluck("G2", 0.26))
pad(G, 21, 5)

# 26-27: the stamp.
at(26, ms.marimba(hz("C3"), 2.0, 0.4))
at(26, ms.bell(hz("C4"), 1.8, 0.05))
pad(["C3", "G3", "E4"], 26, 2)

# 28-33: C quarter notes under the membership card.
for b, n in zip(range(28, 34), ["C4", "E4", "G4", "E4", "C4", "G4"]):
    at(b, mallet(n, 0.45, 0.19))
at(28, pluck("C3", 0.24))
at(32, pluck("C3", 0.2))
for b in (28, 30, 32):
    at(b, kick(0.16))
pad(C, 28, 6)

# 34-43: one chord per tap in Settings.
for start, beats, chord, root in [(34, 2, ["C4", "E4", "G4", "C5"], "C3"), (36, 2, ["A3", "C4", "E4", "A4"], "A2"),
                                   (38, 2, ["F3", "A3", "C4", "F4"], "F2"), (40, 2, ["D4", "F4", "A4", "D5"], "D3"),
                                   (42, 2, ["G3", "B3", "D4", "G4"], "G2")]:
    for k in range(beats * 4):
        at(start + k / 4, mallet(chord[k % 4], 0.3, 0.15 if k % 4 == 0 else 0.11))
    at(start, pluck(root, 0.26))
    at(start, kick(0.16))
    pad(chord[:3], start, beats)

# 44-50: the montage.
for b, cell in [(44, ["C4", "G4"]), (45, ["E4", "C5"]), (46, ["A3", "E4"]), (47, ["C4", "A4"]), (48, ["F3", "C4"]),
                (49, ["A3", "F4"]), (50, ["G3", "D4"])]:
    at(b, mallet(cell[0], 0.34, 0.2))
    at(b + 0.5, mallet(cell[1], 0.3, 0.15))
    at(b, kick(0.22))
    at(b + 0.5, shaker())
for b, n in [(44, "C3"), (46, "A2"), (48, "F2"), (50, "G2")]:
    at(b, pluck(n, 0.26))

# 51-53: the end card, the final chord on 53.
at(51, mallet("C4", 0.45, 0.17))
at(52, mallet("E4", 0.45, 0.15))
for k, n in enumerate(["C3", "G3", "C4", "E4", "G4", "C5"]):
    at(53 + k * 0.06, ms.marimba(hz(n), 1.9, 0.22 if k < 2 else 0.15))
for n, v in [("C5", 0.09), ("E5", 0.08), ("G5", 0.07), ("C6", 0.04)]:
    at(53.12, ms.bell(hz(n), 1.8, v))
pad(["C3", "G3", "E4"], 53, 6)

# A small room, a fade over the last 0.5 s, a gentle soft limiter, -6 dBFS peak.
wet = out[:]
for delay, fb in [(0.043, 0.28), (0.071, 0.22)]:
    d = int(RATE * delay)
    for i in range(d, len(wet)):
        wet[i] += wet[i - d] * fb
mix = [0.82 * a + 0.18 * b for a, b in zip(out, wet)]
fade = int(RATE * 0.5)
for i in range(fade):
    mix[-1 - i] *= i / fade
peak = max(abs(s) for s in mix)
mix = [math.tanh(1.6 * s / peak) / math.tanh(1.6) * peak for s in mix]
peak = max(abs(s) for s in mix)
scale = 0.5 / peak
dest = ROOT / "assets" / "sounds" / "music.wav"
with wave.open(str(dest), "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767)) for s in mix))
print(f"{dest.name}: {len(mix) / RATE:.2f} s, peak scaled by {scale:.2f}")
