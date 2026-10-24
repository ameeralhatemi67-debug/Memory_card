// The cuts of Video 1, one schedule each. Read by the three scenes (window.MC_PLANS) and, as JSON, by
// tools/build_cuts.py (sound placement, root files) and tools/make_music.py. Numbers are beats on the
// 104 BPM grid (beat n = n x 60 / 104 s) unless a key says "s" (seconds). null = the cut skips that beat.
window.MC_PLANS = {
  "full": {
    "label": "20 s", "duration": 20, "music": "music.wav",
    "hook": { "fadeS": 0.7, "staggerS": 0.04, "riseS": [1.5, 1.8, 2.3], "dropS": 2.16, "land": 4, "pullS": [2.45, 0.95], "uiS": 2.7, "swapS": 2.72 },
    "startN": 10,
    "think": 6, "tap": 8, "knew": 10, "release1": 12, "notYet": 13, "release2": 15,
    "montage": [["f-m0", 18], ["f-m1", 19], ["f-m2", 20], ["f-m3", 21], ["f-m4", 22], ["f-m5", 23], ["f-m6", 24], ["f-m7", 25]],
    "stamp": 26, "sealY": 0, "streak": 28,
    "wipe": 30, "deals": [31, 31.5, 32], "flightS": 0.4, "endS": [0.04, 0.29, 0.44]
  },
  "short": {
    "label": "15 s", "duration": 15, "music": "music-15s.wav",
    "hook": { "fadeS": 0.7, "staggerS": 0.04, "riseS": [1.5, 1.8, 2.3], "dropS": 2.16, "land": 4, "pullS": [2.45, 0.95], "uiS": 2.7, "swapS": 2.72 },
    "startN": 14,
    "think": 5.5, "tap": 7, "knew": 8, "release1": 10, "notYet": 11, "release2": 13,
    "montage": [["f-m0", 16], ["f-m2", 17], ["f-m3", 18], ["f-m5", 19]],
    "stamp": 20, "sealY": 0, "streak": null,
    "wipe": 22, "deals": [23, 23.5, 24], "flightS": 0.36, "endS": [0.0, 0.1, 0.18]
  },
  "bumper": {
    "label": "6 s", "duration": 6, "music": "music-6s.wav",
    "hook": { "fadeS": 0.55, "staggerS": 0.03, "riseS": [1.05, 1.3, 1.7], "dropS": 1.58, "land": 3, "pullS": [1.85, 0.75], "uiS": 2.0, "swapS": null },
    "startN": 19,
    "think": null, "tap": null, "knew": null, "release1": null, "notYet": null, "release2": null,
    "montage": [],
    "stamp": 5, "sealY": 60, "streak": null,
    "wipe": 6, "deals": [7, 7.5, 8], "flightS": 0.36, "endS": [0.0, 0.1, 0.18]
  }
};

// Where the camera sits for each frame shape: [x, y, scale] of the 390 x 844 phone (transform origin 0 0).
// The hook is a close-up on the phone's wall; the shot is the whole phone.
window.MC_FORMATS = {
  "portrait": { "w": 1080, "h": 1920, "hook": [-220.2, -18, 4.6], "shot": [212.4, 472.96, 1.68] },
  "square": { "w": 1080, "h": 1080, "hook": [-214.9, -261.8, 4.09], "shot": [62, 33.6, 1.2] }
};
