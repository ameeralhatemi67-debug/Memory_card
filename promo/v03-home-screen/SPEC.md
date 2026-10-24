# Video 3 · Your home screen remembers too — SPEC

Source brief: `docs/marketing/promo_videos.md` §0 (motion system) and §3 (beat sheet). The owner's beat sheet is
the storyboard. Every widget on screen is the app's own drawing: the debug dump (`DebugReceiver` DUMP with
`pieces`) renders each widget's face and drawing on the emulator at the Pixel grid sizes (Grid A, 2.625 px per dp),
leaves out the moving pieces and writes where they go; the video puts them back with the launcher's own motion
(`res/anim`, `res/animator`, the ProgressBar durations in `wg_scene_fxb.xml`). Settings › Widgets is a screen
capture of the app on the emulator.

```text
GOAL:    a stranger sees Memory Card work without opening it: a card answered on the home screen, the goal
         stamped, the membership card turned, the colours changed, and leaves with "13 widgets on Android".
OUTPUT:  HyperFrames, 1080 x 1920 (9:16 only, the brief), 30 fps.
TIME:    32.0 s x 30 = 960 frames. Music 108 BPM: 1 beat = 0.5556 s = 16.667 frames (3 beats = 50 frames);
         1 bar = 2.222 s. Beat n at round(n x 16.667) frames.
LOOK:    the world of Video 1 (felt #EAEAEA at 14 %, window light, 2.5 % grain); Bernard titles 96 px on
         96 px lines, Barlow 600 sub-lines 44 px, flush left at x = 134 from y = 240; two lines end at y 432,
         15 px above the phone's bezel at the tightest push-in.
         phone   neutral body #1B1B1B, 10 dp bezel, 50 dp corners, screen 411 x 914 dp (Pixel-class, the size
                 the widgets were measured on); shown at 1.5x (617 x 1371 px), screen top at y = 470.
         wallpaper  a calm slate gradient: radial #A8B8CC (top left) -> #7088A4 -> #5E7592 (bottom right) by
                 day, #2A3443 -> #1B222D by night; 3 % grain.
         home    status bar (9:41, signal, battery) in paper; Grid A: columns at x = 25.5 + 94 c dp, rows at
                 y = 64 + 125 r dp, widget size (94 c - 16) x (125 r - 17) dp; dock at y = 790 dp (the app's
                 icon + three plain rounded squares), page dots above it, gesture pill at y = 896 dp.
         page 1  Streak 4x1 (r0) · Daily goal seal 2x2 (r1-2, c0-1) · Quick actions 2x2 (r1-2, c2-3) · Today 4x2 (r3-4)
         page 2  Quick card 4x2 (r0-1) · Membership card 4x2 (r2-3) · Seals 4x1 (r4)
OBJECTS: each widget = face (its colour, 22 dp corners, a pill when narrow) + moving pieces behind the drawing
         (SEAL wax 48 points turning 360 deg in 32 s; FLAME / FLAME_OUTLINE flickering: scaleY 1-1.13 430 ms,
         scaleX 1-0.9 590 ms, rotation +-4 deg 810 ms, all yoyo, pivot 12,21 of 24) + the drawing (_ink PNG) +
         pieces in front (PULSE ring 0.6->1.06 and alpha 0.95->0 in 1.9 s; SHEEN band -80 -> 290 in the first
         22 % of 7 s). The hand of cards: the nav bar's five cards (66 x 98 dp, -16 -8 0 8 16 deg about a pivot
         403 dp down) at 1.6x.
MOTION:  as Video 1 (paper ease, springy settle, the stamp keyframes). Widget turn = the launcher's:
         out scaleX 1 -> 0.02 in 170 ms accelerate, in 0.02 -> 1 in 210 ms decelerate from 160 ms.
         Widget swap = the launcher's: out 300 ms accelerate to x -24 %, y +7 %, -11 deg, 0.86, alpha 0; in from
         70 ms, 420 ms overshoot from x +24 %, y +7 %, 11 deg, 0.86, alpha 0 -> 1 in 250 ms.
         Home paging: 0.45 s power3.inOut, the wallpaper drifts 30 dp the other way.
SHOTS:   (beats on the 108 grid)
  0-2.5    HOOK. Frame 0: "Your home screen / remembers too." over the phone, page 1 empty, the hand of cards
           peeking at the bottom of the screen. The hand rises (springy). Sound: whoosh.
  3-6      One card per beat leaves the hand, flips edge-on mid-air and unfolds into a widget in its cell: Account
           (red) -> Streak 4x1 on 3, Home (blue) -> Seal 2x2 on 4, Lab (green) -> Quick actions on 5, Shop (peach)
           -> Today 4x2 on 6. Each widget's own motion starts as it lands. `card` x4. The + card sinks away on 7.
  7-11     "Widgets that keep you going." Hold on the full page.
  12-20    QUICK CARD. Swipe to page 2 (12), push in to 2.35x on the Quick card (13). "Review without opening the
           app." Tap Reveal on 15: the card turns to "the apple" (`flip`). Tap Got it on 18: it turns to the next
           card, "das Wasser · 1 done · 2 left" (`good`).
  20-27    SEAL. Pull back (20), swipe to page 1 (21), push in to 2.4x on the seal (22). "Your goal, at a glance."
           The ring sweeps 13 -> 20 (23-25.5) with the count ticking; on 26 the red DONE seal stamps
           (keyframes + 2-frame shake, `stamp`, `fanfare`) and the face reads "Goal met".
  27.5-33  MEMBERSHIP. Pull back, swipe to page 2, push in on the membership card. "Your card. Both sides."
           Tap on 29.5: it swaps to its back (five weeks, the streak); tap on 32: it swaps back. `card` x2.
  34-43    MAKE THEM YOURS. The frame splits: Settings › Widgets (the app on the emulator, Theme + Accent rows)
           above, page 1 below. Tap blue on 36, green on 38: every widget changes accent in a wave (60 ms apart
           by distance from the top). Tap Dark on 40: the widgets turn to their night faces; Light on 42.
           43.4-44: Settings lifts away with the title and the camera falls into the screen (2.8x, power2.in):
           the montage cuts in on its wallpaper on 44.
  44-50    MONTAGE. One widget per beat, close on the wallpaper, its motion running: Next two weeks, Activity,
           Card of the day, Seals, Decks, the tall Streak flame, the Quick Settings tile (the tile alone,
           cut from the emulator's panel at 1.7x). "13 widgets" + "and a
           Quick Settings tile · Android". A hit per cut.
  51-57.6  END CARD (Video 1's): paper sheet, the logo dealt on 52, 52.5, 53, "Memory Card", "On your home
           screen.", "Coming to Android". Still for the last second.
BANNED:  invented widget UI (every face is a dump); a branded launcher or phone; glow; floating idles on titles;
         widgets that move without the launcher's own motion; cross-dissolves between worlds.
QA:      f0 title + empty page; beats 3-6 a card mid-flip; 11 full page 1; 15-16 the turn; 25 the sweep;
         26 the stamp; 30 the swap; 36-38 the accent wave; 40 night faces; each montage beat; 57 end card.
```
