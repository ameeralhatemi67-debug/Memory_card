"""The music beds for Video 1's cuts (104 BPM, C major), made with the app's own synth voices
(tools/make_sounds.py: marimba, bell), so the bed and the app's sounds are one family.

    python promo/v01-you-will-forget-this/tools/make_music.py [full|short|bumper|all]

Writes assets/sounds/<plan music>.wav (44.1 kHz, mono, 16-bit) at each cut's length (assets/plans.js).
Placeholder beds: swap a file for a licensed track at 96-110 BPM and keep the <audio id="music"> element.

The 20 s form (beats from 0, one beat = 60/104 s):
  0-3    one low marimba C3 ringing, room tone (the hook)
  4-7    quarter-note pulse on C (the card catches THIS, camera pulls back)
  8-17   eighth-note ostinato Am | F | G, soft kick on 1 and 3, plucked bass (the gesture)
  18-25  sixteenth-note arpeggios climbing C | Am | F | G7, kick every beat, shaker (the montage)
  26-27  held low C under the stamp and the fanfare, no percussion
  28-31  the pulse returns on C (the streak, the end card arrives)
  32     final C chord, marimba roll + bells, rings out to the end
The 15 s and 6 s beds are the same pieces placed on their own plans' beats.
"""
import json
import math
import pathlib
import struct
import sys
import wave

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT.parents[1] / "tools"))
import make_sounds as ms  # noqa: E402  (the app's synth: marimba(), bell(), tone(), noise())

RATE = ms.RATE
BEAT = 60 / 104
PLANS_JS = (ROOT / "assets" / "plans.js").read_text(encoding="utf-8")
PLANS = json.loads(PLANS_JS[PLANS_JS.index("{"):PLANS_JS.index("};") + 1])

out = []


def at(beat, samples, gain=1.0):
    start = int(round(beat * BEAT * RATE))
    for i, v in enumerate(samples):
        j = start + i
        if 0 <= j < len(out):
            out[j] += v * gain


def hz(name):
    """'C4' -> frequency (A4 = 440)."""
    notes = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semis = notes[name[0]] + (1 if "#" in name else 0) - (1 if name[1] == "b" else 0)
    octave = int(name[-1])
    return 440.0 * 2 ** ((semis + 12 * (octave - 4)) / 12)


def mallet(name, sec=0.42, vol=0.3):
    """The app's marimba, plus a soft wooden knock so the attack reads on a phone speaker."""
    f = hz(name)
    body = ms.marimba(f, sec, vol)
    knock = ms.noise(0.012, vol * 0.25, decay=9, low=0.2, high=0.7)
    return ms.mix(body, knock)


def pluck(name, vol=0.32):
    """Plucked bass: harmonics up to the 4th so it is heard above 150 Hz."""
    return ms.tone(hz(name), 0.5, vol, decay=6.5, attack=0.003, partials=((1, 1.0), (2, 0.55), (3, 0.3), (4, 0.15)))


def kick(vol=0.24):
    return ms.mix(ms.tone(118, 0.16, vol, decay=6, attack=0.001, glide_to=52),
                  ms.noise(0.01, vol * 0.3, decay=8, low=0.1, high=0.6))


def shaker(vol=0.05):
    return ms.noise(0.05, vol, decay=7, attack=0.004, low=0.45, high=0.95)


def pad(names, beat, beats, vol=0.045):
    """A soft sustained chord, so the marimba's gaps are never silence."""
    sec = beats * BEAT + 0.35
    for n in names:
        at(beat, ms.tone(hz(n), sec, vol, decay=1.6, attack=0.18, partials=((1, 1.0), (2, 0.22), (3, 0.06))))


def hook(length):
    at(0, ms.marimba(hz("C3"), 2.4, 0.34))
    at(0, ms.marimba(hz("C4"), 1.4, 0.12))
    at(0, ms.noise(length, 0.012, decay=0.01, attack=0.5, low=0.01, high=0.08))  # room tone


def ostinato(start, cell, bass, beats):
    """Eighth notes on one chord, plucked bass on 1 (and 3), soft kick on every other beat."""
    for k in range(beats * 2):
        at(start + k / 2, mallet(cell[k % 4], 0.38, 0.22 if k % 2 == 0 else 0.17))
    at(start, pluck(bass))
    if beats >= 4:
        at(start + 2, pluck(bass, 0.22))
    for k in range(0, beats, 2):
        at(start + k, kick(0.2))


def climb(cells, roots):
    """Sixteenth arpeggios, one cell a beat, kick on the beat, shaker on the off-beats."""
    for b, cell in cells.items():
        for k, n in enumerate(cell):
            at(b + k / 4, mallet(n, 0.3, 0.2 if k == 0 else 0.15))
        at(b, kick(0.22))
        at(b + 0.5, shaker())
        at(b + 0.75, shaker(0.035))
        if b in roots:
            at(b, pluck(roots[b], 0.3))


def hold(beat):
    """Held low C under the stamp (the fanfare plays on top), no percussion."""
    at(beat, ms.marimba(hz("C3"), 2.0, 0.42))
    at(beat, ms.bell(hz("C4"), 1.8, 0.05))


def final(beat):
    """The last chord: a quick roll up and soft bells, ringing to the end."""
    for k, n in enumerate(["C3", "G3", "C4", "E4", "G4", "C5"]):
        at(beat + k * 0.06, ms.marimba(hz(n), 1.9, 0.22 if k < 2 else 0.15))
    for n, v in [("C5", 0.09), ("E5", 0.08), ("G5", 0.07), ("C6", 0.04)]:
        at(beat + 0.12, ms.bell(hz(n), 1.6, v))


def hum():
    at(0, ms.tone(hz("C3"), 2.3, 0.03, decay=1.2, attack=0.4, partials=((1, 1.0), (2, 0.3))))  # under the hook


C, AM, F, G = ["C4", "E4", "G4"], ["A3", "C4", "E4"], ["F3", "A3", "C4"], ["G3", "B3", "D4"]


def full():
    hook(20.0)
    for b, n in zip(range(4, 8), ["C4", "G4", "E4", "G4"]):
        at(b, mallet(n, 0.45, 0.24))
    ostinato(8, ["A3", "E4", "C5", "E4"], "A2", 4)
    ostinato(12, ["F3", "C4", "A4", "C4"], "F2", 4)
    ostinato(16, ["G3", "D4", "B4", "D4"], "G2", 2)
    climb({18: ["C4", "E4", "G4", "C5"], 19: ["E4", "G4", "C5", "E5"],
           20: ["A4", "C5", "E5", "A5"], 21: ["C5", "E5", "A5", "C6"],
           22: ["F4", "A4", "C5", "F5"], 23: ["A4", "C5", "F5", "A5"],
           24: ["G4", "B4", "D5", "G5"], 25: ["B4", "D5", "F5", "G5"]},
          {18: "C3", 20: "A2", 22: "F2", 24: "G2"})
    hold(26)
    for b, n in zip(range(28, 32), ["C4", "E4", "G4", "E4"]):
        at(b, mallet(n, 0.45, 0.2))
    at(28, pluck("C3", 0.26))
    at(28, kick(0.24))
    at(30, kick(0.2))
    final(32)
    for names, beat, beats in [(C, 4, 4), (AM, 8, 4), (F, 12, 4), (G, 16, 2), (C, 18, 2), (AM, 20, 2), (F, 22, 2),
                               (G + ["F4"], 24, 2), (["C3", "G3", "E4"], 26, 2), (C, 28, 4)]:
        pad(names, beat, beats)
    hum()


def short():
    # Tap on 7, swipes released on 10 and 13, montage releases 16-19, stamp 20, end card 22, last deal 24.
    hook(15.0)
    for b, n in zip(range(4, 7), ["C4", "G4", "E4"]):
        at(b, mallet(n, 0.45, 0.24))
    ostinato(7, ["A3", "E4", "C5", "E4"], "A2", 4)
    ostinato(11, ["F3", "C4", "A4", "C4"], "F2", 3)
    ostinato(14, ["G3", "D4", "B4", "D4"], "G2", 2)
    climb({16: ["C4", "E4", "G4", "C5"], 17: ["A4", "C5", "E5", "A5"],
           18: ["F4", "A4", "C5", "F5"], 19: ["B4", "D5", "F5", "G5"]},
          {16: "C3", 17: "A2", 18: "F2", 19: "G2"})
    hold(20)
    for b, n in [(22, "C4"), (23, "E4")]:
        at(b, mallet(n, 0.45, 0.2))
    at(22, pluck("C3", 0.24))
    at(22, kick(0.22))
    final(24)
    for names, beat, beats in [(C, 4, 3), (AM, 7, 4), (F, 11, 3), (G, 14, 2), (C, 16, 1), (AM, 17, 1), (F, 18, 1),
                               (G + ["F4"], 19, 1), (["C3", "G3", "E4"], 20, 2), (C, 22, 2)]:
        pad(names, beat, beats)
    hum()


def bumper():
    # THIS lands on 3, the seal stamps on 5, the end card arrives on 6, the last card is dealt on 8.
    hook(6.0)
    at(3, mallet("G4", 0.5, 0.22))
    at(4, mallet("E4", 0.5, 0.2))
    hold(5)
    at(6, mallet("C4", 0.45, 0.18))
    final(8)
    pad(C, 3, 2, 0.035)
    pad(["C3", "G3", "E4"], 5, 3)
    hum()


def render(cut):
    global out
    plan = PLANS[cut]
    ms.rng.seed(47)  # the same noise every run (and the 20 s bed identical to the first delivery)
    out = [0.0] * int(RATE * plan["duration"])
    {"full": full, "short": short, "bumper": bumper}[cut]()

    # A small room: two short feedback delays, then a fade over the last 0.4 s.
    wet = out[:]
    for delay, fb in [(0.043, 0.28), (0.071, 0.22)]:
        d = int(RATE * delay)
        for i in range(d, len(wet)):
            wet[i] += wet[i - d] * fb
    mixdown = [0.82 * a + 0.18 * b for a, b in zip(out, wet)]
    fade = int(RATE * 0.4)
    for i in range(fade):
        mixdown[-1 - i] *= i / fade

    # A gentle soft limiter: the downbeats (kick + bass + marimba together) stop setting the level of the whole bed.
    peak = max(abs(s) for s in mixdown)
    drive = 1.6
    mixdown = [math.tanh(drive * s / peak) / math.tanh(drive) * peak for s in mixdown]

    peak = max(abs(s) for s in mixdown)
    scale = 0.5 / peak  # peak at about -6 dBFS: the app sounds sit on top
    dest = ROOT / "assets" / "sounds" / plan["music"]
    with wave.open(str(dest), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767)) for s in mixdown))
    print(f"{dest.name}: {len(mixdown) / RATE:.2f} s, peak scaled by {scale:.2f}")


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    for cut in (["full", "short", "bumper"] if which == "all" else [which]):
        render(cut)
