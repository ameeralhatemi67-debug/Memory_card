"""Mixes index.html's <audio> clips (start, duration, volume) the way the renderer does, to measure levels
without rendering the picture.

    python promo/v01-you-will-forget-this/tools/mix_preview.py [project dir] [out.wav]

The project dir defaults to this one (the 20 s cut); the other cuts live in promo/build/v01-<cut>.

Prints integrated loudness and true peak (ffmpeg ebur128). Target for social: -16 to -14 LUFS, <= -1 dBTP.
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parents[1]
html = (ROOT / "index.html").read_text(encoding="utf-8")
clips = []
for tag in re.findall(r"<audio [^>]*>", html):
    attr = dict(re.findall(r'([\w-]+)="([^"]*)"', tag))
    clips.append((attr["src"], float(attr["data-start"]), float(attr.get("data-volume", "1"))))

out = sys.argv[2] if len(sys.argv) > 2 else str(ROOT / "renders" / "mix_preview.wav")
(ROOT / "renders").mkdir(exist_ok=True)
args = ["ffmpeg", "-hide_banner", "-y"]
for src, _, _ in clips:
    args += ["-i", str(ROOT / src)]
chains = [f"[{i}:a]aresample=48000,volume={vol},adelay={int(start * 1000)}:all=1[a{i}]" for i, (_, start, vol) in enumerate(clips)]
length = float(re.search(r'data-composition-id="main"[^>]*data-duration="([\d.]+)"', html).group(1))
mix = "".join(f"[a{i}]" for i in range(len(clips))) + f"amix=inputs={len(clips)}:normalize=0:duration=longest,atrim=0:{length}[m]"
args += ["-filter_complex", ";".join(chains + [mix]), "-map", "[m]", out]
subprocess.run(args, check=True, capture_output=True)
meter = subprocess.run(["ffmpeg", "-hide_banner", "-i", out, "-af", "ebur128=peak=true", "-f", "null", "-"],
                       capture_output=True, text=True).stderr
summary = meter[meter.rfind("Summary:"):]
print(" ".join(line.strip() for line in summary.splitlines() if line.strip().startswith(("I:", "Peak:"))))
