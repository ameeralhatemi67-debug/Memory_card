"""Runs the app's debug widget dump on a running emulator (debug build installed), one widget class per broadcast,
for each accent, and waits until each is complete.

    python promo/v03-home-screen/tools/dump_widgets.py red blue green
    adb pull /sdcard/Android/data/com.memorycard.app/files/widget_dump <dump dir>
    python promo/v03-home-screen/tools/build_widgets.py <dump dir>/widget_dump

Set ADB if adb is not at the default below. Each class writes its sizes x 9 sample days x day/night x 3 files
(the picture, the drawing alone, the pieces JSON).
"""
import os
import subprocess
import sys
import time

ADB = os.environ.get("ADB", r"D:/app/Android/Sdk/platform-tools/adb.exe")
ENV = dict(os.environ, MSYS_NO_PATHCONV="1")
BASE = "/sdcard/Android/data/com.memorycard.app/files/widget_dump"
ONLY = ("SealWidget,StreakWidget,StreakTallWidget,TodayWidget,QuickCardWidget,ActionsGridWidget,ActivityWidget,"
        "ForecastWidget,MembershipWidget,CardOfDayWidget,SealsWidget,DecksWidget,ActionsWidget")
SIZES = {"SealWidget": 6, "StreakWidget": 8, "StreakTallWidget": 4, "TodayWidget": 4, "QuickCardWidget": 4,
         "ActionsGridWidget": 2, "ActivityWidget": 6, "ForecastWidget": 4, "MembershipWidget": 2, "CardOfDayWidget": 4,
         "SealsWidget": 4, "DecksWidget": 6, "ActionsWidget": 8}  # Grid A + Grid B sizes


def sh(*args):
    return subprocess.run([ADB, *args], capture_output=True, env=ENV).stdout.decode("utf-8", "replace")


def count(sub):
    out = sh("shell", f"ls {BASE}/{sub} 2>/dev/null | wc -l").strip()
    return int(out or 0)


# One widget per broadcast: a whole dump runs past the 60 s an async broadcast may take, and Android kills it.
for acc in sys.argv[1:]:
    look = "{}" if acc == "red" else '{"accent":"%s"}' % acc
    for cls, sizes in SIZES.items():
        sub = f"{acc}/{cls}"
        expected = sizes * 9 * 2 * 3
        sh("shell", "am", "broadcast", "-n", "com.memorycard.app/com.memorycard.memory_card.DebugReceiver",
           "-a", "com.memorycard.debug.DUMP", "--es", "only", cls, "--ez", "pieces", "true", "--es", "sub", sub,
           "--es", "look", f"'{look}'")
        last, still, t0 = -1, 0, time.time()
        while True:
            time.sleep(2)
            n = count(sub)
            still = still + 1 if n == last else 0
            last = n
            if n >= expected:
                break
            if still >= 8 or time.time() - t0 > 55:
                print(f"{sub}: STOPPED at {n}/{expected}", flush=True)
                break
        print(f"{sub}: {last}/{expected} in {time.time() - t0:.0f} s", flush=True)
