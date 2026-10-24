"""Writes the root file of every cut of Video 1 from assets/plans.js: the scenes it mounts (with the cut and
frame shape as variables) and the app's sounds placed one frame after the picture that causes them.

    python promo/v01-you-will-forget-this/tools/build_cuts.py

The 20 s 9:16 cut is this project's index.html. HyperFrames wants one root file per project, so every other
cut becomes its own small project in promo/build/v01-<cut>/ (gitignored): its index.html plus copies of
assets/ and compositions/. Edit the plans, the scenes or this file, then run it again before rendering;
never hand-edit a generated root file.
"""
import json
import pathlib
import shutil
import wave

ROOT = pathlib.Path(__file__).resolve().parents[1]
js = (ROOT / "assets" / "plans.js").read_text(encoding="utf-8")
PLANS = json.loads(js[js.index("{"):js.index("};") + 1])

BUILD = ROOT.parent / "build"
# project folder (None = this one), cut, frame shape, title
CUTS = [
    (None, "full", "portrait", "Video 1 · You will forget this · 20 s 9:16"),
    ("v01-15s", "short", "portrait", "Video 1 · You will forget this · 15 s 9:16"),
    ("v01-6s", "bumper", "portrait", "Video 1 · You will forget this · 6 s bumper 9:16"),
    ("v01-square", "full", "square", "Video 1 · You will forget this · 20 s 1:1"),
]
SIZE = {"portrait": (1080, 1920), "square": (1080, 1080)}
FRAME = 1 / 30


def B(n):
    return n * 60 / 104


def length(name):
    with wave.open(str(ROOT / "assets" / "sounds" / f"{name}.wav")) as w:
        return w.getnframes() / w.getframerate()


def sounds(p):
    """(id, sound, start s, volume) for one cut, from its plan."""
    h, out = p["hook"], []
    out.append(("sx-rise", "whoosh", h["riseS"][0] + 0.18, 0.8))
    out.append(("sx-land", "pop", B(h["land"]) + FRAME, 0.85))
    if p["tap"] is not None:
        r1, r2 = B(p["release1"]), B(p["release2"])
        out += [
            ("sx-flip1", "flip", B(p["tap"]) + FRAME, 0.8),
            ("sx-lock1", "tick", r1 - 0.288 + FRAME, 1),  # the 60 % commit line
            ("sx-good1", "good", r1 + FRAME, 0.78),
            ("sx-flip2", "flip", B(p["notYet"]) + FRAME, 0.8),
            ("sx-lock2", "tick", r2 - 0.264 + FRAME, 1),
            ("sx-again1", "again", r2 + FRAME, 0.85),
            ("sx-tuck", "card", r2 + 0.778, 0.9),  # the missed card snaps back into the stack
        ]
    hits = [s for s in p["montage"] if s[0] != "f-m3"]
    for k, (sid, beat) in enumerate(p["montage"]):
        if sid == "f-m3":
            out.append((f"sx-m{k}", "again", B(beat) + FRAME, 0.8))
        else:
            j = hits.index([sid, beat])
            out.append((f"sx-m{k}", "good" if j % 2 == 0 else "easy", B(beat) + FRAME, 0.7 if j == len(hits) - 1 else 0.66))
    out.append(("sx-stamp", "stamp", B(p["stamp"]) + FRAME, 0.62))
    out.append(("sx-fanfare", "fanfare", B(p["stamp"]) + 0.2, 0.7))
    if p["streak"] is not None:
        out.append(("sx-flap", "tick", B(p["streak"] + 0.5) + FRAME, 1))
    out.append(("sx-wipe", "whoosh", B(p["wipe"]) + 0.002, 0.8))
    for k, d in enumerate(p["deals"]):
        out.append((f"sx-deal{k + 1}", "card", B(d) + FRAME, 0.9))
    return out


def page(cut, shape, title):
    p = PLANS[cut]
    w, h = SIZE[shape]
    dur = p["duration"]
    vals = json.dumps({"cut": cut, "format": shape})
    hosts = [f'''      <div id="film" data-composition-id="film" data-composition-src="compositions/film.html"
        data-start="0" data-duration="{dur}" data-track-index="1" data-track-kind="graphics" data-width="{w}" data-height="{h}"
        data-variable-values='{vals}' style="z-index:1"></div>''']
    if p["tap"] is not None:
        hosts.append(f'''      <div id="titles" data-composition-id="titles" data-composition-src="compositions/titles.html"
        data-start="0" data-duration="{round(B(p["wipe"]) + 0.7, 4)}" data-track-index="2" data-track-kind="graphics" data-width="{w}" data-height="{h}"
        data-variable-values='{vals}' style="z-index:2"></div>''')
    start = round(B(p["wipe"]), 4)
    hosts.append(f'''      <div id="endcard" data-composition-id="endcard" data-composition-src="compositions/endcard.html"
        data-start="{start}" data-duration="{round(dur - start, 4)}" data-track-index="3" data-track-kind="graphics" data-width="{w}" data-height="{h}"
        data-variable-values='{vals}' style="z-index:3"></div>''')
    audio = [f'      <audio id="music" src="assets/sounds/{p["music"]}" data-start="0" data-duration="{dur:.3f}" data-track-index="10" data-volume="1.5"></audio>']
    lanes = []  # end time of the last clip on each Studio lane, so no two clips overlap on one lane
    for aid, name, t, vol in sounds(p):
        d = min(round(length(name) + 0.005, 3), round(dur - t, 3))
        lane = next((i for i, end in enumerate(lanes) if end <= t), len(lanes))
        lanes[lane:lane + 1] = [t + d]
        audio.append(f'      <audio id="{aid}" src="assets/sounds/{name}.wav" data-start="{t:.3f}" data-duration="{d:.3f}" data-track-index="{11 + lane}" data-volume="{vol}"></audio>')
    nl = "\n"
    return f'''<!doctype html>
<!-- Generated by tools/build_cuts.py from assets/plans.js: edit those, then run it again. -->
<html lang="en" data-resolution="{"square" if shape == "square" else "portrait"}">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width={w}, height={h}" />
    <title>Memory Card · {title}</title>
    <script src="https://cdn.jsdelivr.net/npm/gsap@3.14.2/dist/gsap.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/gsap@3.14.2/dist/CustomEase.min.js"></script>
    <script src="assets/plans.js"></script>
    <style>
      * {{ margin: 0; padding: 0; box-sizing: border-box; }}
      html, body {{ margin: 0; width: {w}px; height: {h}px; overflow: hidden; background: #EAEAEA; }}
      #root {{ position: relative; width: 100%; height: 100%; }}
      /* A faint paper grain over the whole frame (the brief: 2-3 %). */
      #grain {{ position: absolute; inset: 0; z-index: 50; pointer-events: none; background-image: url("assets/textures/grain_fine.png"); background-size: 256px 256px; opacity: 0.12; mix-blend-mode: multiply; }}
    </style>
  </head>
  <body>
    <div id="root" data-composition-id="main" data-start="0" data-duration="{dur}" data-width="{w}" data-height="{h}">
      <!-- Scenes: one plan (assets/plans.js) and one frame shape for all of them. -->
{nl.join(hosts)}
      <div id="grain"></div>

      <!-- Music bed: 104 BPM marimba made with the app's synth (tools/make_music.py). Swap the file to change it. -->
      <!-- The app's own sounds (app/assets/sounds), each one frame after the picture that causes it. -->
{nl.join(audio)}
    </div>
    <script>
      window.__timelines = window.__timelines || {{}};
      window.__timelines["main"] = gsap.timeline({{ paused: true }});
    </script>
  </body>
</html>
'''


for folder, cut, shape, title in CUTS:
    dest = ROOT if folder is None else BUILD / folder
    if folder is not None:
        for sub in ("assets", "compositions"):
            shutil.rmtree(dest / sub, ignore_errors=True)
            shutil.copytree(ROOT / sub, dest / sub)
        for f in ("hyperframes.json", "package.json"):
            shutil.copy2(ROOT / f, dest / f)
        (dest / "meta.json").write_text(json.dumps({"id": folder, "name": folder}, indent=2) + "\n", encoding="utf-8")
    (dest / "index.html").write_text(page(cut, shape, title), encoding="utf-8")
    print(dest.relative_to(ROOT.parent), cut, shape, PLANS[cut]["duration"], "s")
