"""Masters a rendered video's sound for social platforms: two-pass loudness normalisation to -15 LUFS with a
-1.5 dBTP ceiling (a soft limiter catches the hits first). The picture is copied untouched.

    python promo/tools/master.py renders/in.mp4 renders/out.mp4

Shared by every promo video.
"""
import json
import subprocess
import sys

src, dst = sys.argv[1], sys.argv[2]
TARGET = "I=-15:TP=-1.5:LRA=11"
pre = "alimiter=limit=0.84:attack=3:release=60:level=disabled"

probe = subprocess.run(["ffmpeg", "-hide_banner", "-i", src, "-af", f"{pre},loudnorm={TARGET}:print_format=json", "-f", "null", "-"],
                       capture_output=True, text=True).stderr
m = json.loads(probe[probe.rfind("{"):probe.rfind("}") + 1])
second = (f"{pre},loudnorm={TARGET}:measured_I={m['input_i']}:measured_TP={m['input_tp']}:measured_LRA={m['input_lra']}"
          f":measured_thresh={m['input_thresh']}:offset={m['target_offset']}:linear=true,aresample=48000")
subprocess.run(["ffmpeg", "-hide_banner", "-y", "-i", src, "-c:v", "copy", "-af", second, "-c:a", "aac", "-b:a", "192k", dst],
               check=True, capture_output=True)
meter = subprocess.run(["ffmpeg", "-hide_banner", "-i", dst, "-af", "ebur128=peak=true", "-f", "null", "-"],
                       capture_output=True, text=True).stderr
summary = meter[meter.rfind("Summary:"):]
print(dst, " ".join(line.strip() for line in summary.splitlines() if line.strip().startswith(("I:", "Peak:"))))
