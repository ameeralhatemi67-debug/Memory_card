# Video 3 · Your home screen remembers too · review (2026-10-24)

Delivered (30 fps, H.264 + AAC, mastered to about -15 LUFS with a -1.5 dBTP ceiling; renders are gitignored,
rebuild with the commands at the end of this file):

| File in `renders/` | Cut | Size | Length | Loudness |
|---|---|---|---|---|
| `MemoryCard-V3-HomeScreen-9x16.mp4` | the master (9:16 only, as the brief asks) | 1080 × 1920 | 32.0 s | -15.2 LUFS, -1.2 dBTP |

## Creative calls

- **The owner's beat sheet is the storyboard** (`docs/marketing/promo_videos.md` §3), re-timed onto a 108 BPM
  grid (one beat = 0.556 s). Every number is in `SPEC.md`.
- **Every widget is the app's own drawing.** The debug build's widget dump (`DebugReceiver` DUMP with
  `pieces`) renders each widget on the emulator at its Grid A size in three layers:
  - the face;
  - the drawing alone (`_ink.png`);
  - a JSON of where the moving pieces go.

  `assets/wgkit.js` puts the pieces back between face and drawing and runs them with the launcher's own
  motion: the seal turns, the flame flickers, the pulse rings and the sheen sweeps. The turn and swap are the
  launcher's `wg_turn_*` and `wg_swap_*` animations. Nothing on screen is redrawn by hand, except the goal
  ring's sweep and count (13 → 20) over the seal. The dump only has the before and after states, so the sweep
  in between is drawn.
- **The hook.** Frame 0 is the title over an empty home screen, with the nav bar's hand of cards peeking from
  the bottom. The hand rises, and on beats 3–6 a card leaves it, turns edge-on mid-air and opens into a widget
  in its cell (`card` ×4):
  - Account → Streak 4×1;
  - Home → Daily goal seal 2×2;
  - Lab → Quick actions 2×2;
  - Shop → Today 4×2.

  The brief's fourth widget, Next two weeks, opens the montage instead, so page 1 is a full grid.
- **Quick card** is on page 2 with the Membership card and Seals: swipe, push in to 2.35×, tap Reveal (the
  card turns to "the apple", `flip`), tap Got it (the next card, "das Wasser · 1 done · 2 left", `good`).
  The page-1 widgets quietly move from 12/20 to 13/20 at the same time.
- **The goal.** Push in to 2.4× on the seal, the ring sweeps 13 → 20 with a soft tick per step, then the red
  DONE seal stamps with the app's keyframes and a 2-frame shake (`stamp`, `fanfare`). Streak, Quick actions
  and Today then refresh to their goal-met faces.
- **Membership card.** Tap, it swaps to its back (five weeks, the streak); tap, it swaps back (`card` ×2).
- **Make them yours.**
  - Settings › Widgets is a crop of the real screen captured on the emulator. It drops in above the phone.
  - Each tap (blue, green, Dark, Light) switches the capture and refreshes page 1 in a wave, 60 ms apart
    from the top down.
  - The night faces are real night dumps.
  - On 43.4 Settings lifts away with the title. The camera falls into the screen (to 2.8×, power2.in, a soft
    whoosh), and the montage cuts in on its wallpaper on beat 44.
- **Montage.** One widget per beat on the full-frame wallpaper, each with its own motion running, a hit per
  cut: Next two weeks, Activity, Card of the day, Seals, Decks, the tall Streak flame, the Quick Settings
  tile. Quick actions is left out because it is already on page 1.
  - The tile is cut from the emulator's real panel at 1.7×, 4 px inside its rim.
  - It reads "19 to go" (the emulator's state), not the brief's "20 to go".
  - Android itself cuts the subtitle off at "tap t…".
- **End card.** Video 1's, moved onto the 108 grid: the paper sheet, the logo dealt on 52, 52.5 and 53, then
  "Memory Card", "On your home screen." and the **placeholder** "Coming to Android" pill.
- **Music** is a placeholder bed made with the app's synth (`tools/make_music.py`). It is a plucky C major at
  108 BPM:
  - one marimba note per widget landing;
  - an Am | F ostinato under the Quick card;
  - a G arpeggio climbing to the stamp;
  - one chord per Settings tap;
  - a kick on every montage cut;
  - the final chord on the third logo card.

  Swap `assets/sounds/music.wav` for a licensed track at 104–112 BPM and keep `<audio id="music">`.

## Measured vs looked at

- `npx hyperframes check`: ok. Lint, runtime, layout, motion and contrast pass; two warnings are kept (below).
- Looked at:
  - snapshots at every beat of the QA list;
  - frame by frame around the turns, the stamp, the swap and the dive;
  - the `--review` sheets (beats, seams, phone sheet);
  - nine frames decoded from the final MP4.
- The two-line titles end at y 432, 15 px above the phone's bezel at the tightest push-in (measured on the
  frame).
- Sound: **measured, not heard.**
  - Final loudness is -15.2 LUFS integrated with a -1.2 dBTP peak. The bed alone is -23.9 LUFS before its
    1.5× volume; the effects alone peak at -5.3 dBFS.
  - Onsets, measured on the final file: first landing 1.675, Reveal 8.330, stamp 14.450, first swap 16.485,
    blue tap 20.000, montage cuts 24.450/26.110/27.780, third logo card 29.450. All within one frame of their
    picture.
- Not checked: playback on a real phone under Reels/TikTok UI, and whether the synthesized bed sounds good.

## Weakest shot / with more time

- The bed is synthesized; a real plucked or pizzicato track at 108 BPM would lift the whole film.
- During each accent and theme wave, a widget's old and new faces cross-fade for about 0.3 s, so text overlaps
  for a few frames. This matches the launcher's fade, but a still frame mid-wave looks doubled.
- The Quick Settings tile is a 1080 px capture enlarged 1.7×, so it is a little softer than the dumped widgets.
  It is on screen for 0.56 s.
- The phone's own small text (widget labels) is under 28 px. It is product UI, not copy; the titles carry the
  words.

## Warnings kept on purpose

- `dead_stretch` 7.88–11.13 s ("nothing on screen changes"). The Quick card turns at 8.33 s and again at
  10.0 s, but a turn covers a small part of the frame and lasts 0.38 s, so the sampler misses it. The hold
  between them (8.7–10.0 s) is reading time for the answer.
- `composition_file_too_large` on `home.html`: the phone, both pages, the hand of cards, the camera and the
  Settings split share one stacking context and one camera, so they stay in one file.

## Tooling added to the app (debug only)

- `DebugReceiver` DUMP takes three new extras: `--es sub <folder>`, `--es look '<json>'` (an accent or theme
  laid over every sample day) and `--ez pieces true`.
- `widgets/Preview.kt` then writes three files per sample: the picture, the drawing alone (`_ink.png`), and a
  JSON with the face colour and corner radius and each moving piece's kind, place and colour.
- Sample days added: `b` (goal met), `d` (Quick card turned), `g` (membership back) and `h` (one card answered).
- `Scene.flatten(night, withFace)` draws the picture without its face.
- `Samples.kt` takes `answered` card ids for the Quick card's inbox.

## Rebuild

```bash
cd promo/v03-home-screen
# Widgets (only to refresh them): emulator running with the debug build installed
python tools/dump_widgets.py red blue green
adb pull /sdcard/Android/data/com.memorycard.app/files/widget_dump <dump dir>
python tools/build_widgets.py <dump dir>/widget_dump      # assets/widgets/*.png + assets/widgets.js
# Film
python tools/make_music.py                               # assets/sounds/music.wav
python tools/build_root.py                               # index.html (scenes + 54 placed sounds)
npx hyperframes render --quality delivery --output renders/v03-raw.mp4
python ../tools/master.py renders/v03-raw.mp4 renders/MemoryCard-V3-HomeScreen-9x16.mp4
```

The Settings and Quick Settings captures in `assets/captures/` are 1080 × 2400 emulator screenshots
(`adb exec-out screencap -p`). `python ../tools/mix_preview.py .` checks levels without rendering.
Bernard MT Condensed is gitignored (commercial): copy `app/assets/fonts/BernardMTCondensed.ttf` to
`assets/fonts/` before rendering on another machine.
