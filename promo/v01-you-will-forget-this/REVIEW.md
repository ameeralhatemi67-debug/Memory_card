# Video 1 · You will forget this · review (2026-10-24)

Delivered: `renders/MemoryCard-V1-YouWillForgetThis-9x16.mp4` (1080 × 1920, 30 fps, 20.0 s, H.264 + AAC,
-14.9 LUFS, -1.4 dBTP). Renders are gitignored. Rebuild them with the commands at the end of this file.

## Creative calls

- **The owner's beat sheet is the storyboard** (`docs/marketing/promo_videos.md` §1), so there are no
  alternative storylines. Every number is in `SPEC.md`.
- **The hook is one continuous take.** "YOU WILL / FORGET / THIS." is set flush left on the phone screen's own
  wall, with the camera at 4.6×. The letters lose their ink left to right. The card stack slides up over THIS
  (ink on the wall becomes paper on the card), THIS drops onto the card with a `pop` on beat 4, and the camera
  pulls back to 1.68× into the phone. The status bar, header and nav arrive with the pull-back, and THIS
  blur-swaps into "el gato".
- **The phone is rebuilt from the app's code** at its logical size (390 × 844): study header, goal bar, stack
  strips 17 px apart, corner ears, the "Back in N cards" chip, the card-hand nav. The colours, Bernard/Barlow
  type, felt wall, window light, drag maths (rotation 0.09°/px, sag, shrink), springy flip and wax-seal
  keyframes all come from `ui/theme.dart`, `ui/motion.dart`, `study_screen.dart` and `celebrate.dart`.
- **Two reveal modes, both real settings.** The hero cards use *flip* mode (the brief asks for a flip). The
  montage cards show *tap* mode's revealed front (picture, hook, peach answer pill), so the anime art and
  crests stay on screen.
- **Not yet? It comes back.** The missed card flies out left, turns face down off screen, and slides back
  under the new top card. It stays there as a red-edged sliver between the bottom layers while the app's chip
  counts "Back in 1…12 cards", then slides fully in.
- **Montage decks.** Demon Slayer (Tanjiro, Nezuko), Flags · Europe (Greece), Flags · Asia (Japan),
  Crests · English Clubs (Tottenham, Wolves) and French · Food (le fromage as the one left swipe, la fraise).
  These follow the brief's "Decks to feature" (anime and football open the big moments). The periodic table
  and capitals from the §1 table are not used. The world floods with each deck's category colour on every
  cut, and the header counts Today 13 → 20.
- **Flights.** The app's fly-off (230 ms, front-loaded ease) clears the screen in one frame. The video uses a
  0.3 s quad ease-out with horizontal motion blur, and the montage cuts 0.07 s after each release, so two
  blurred frames of every throw read.
- **The green and red swipe edges** are a 3 px edge plus an 18 px soft shadow, not a neon glow.
- **The streak** is the home screen's streak pill made big: red flame, a split-flap digit 4 → 5 on beat 28.5,
  and "day streak".
- **End card.** A full-bleed paper sheet slides up over the film, and the three logo cards are dealt from the
  bottom right on beats 31, 31.5 and 32 (`card` ×3). Then come "Memory Card", "Remember it for good." and a
  **placeholder** pill, "Coming to Android". It is the `storeBadge` variable in `compositions/endcard.html`;
  swap it for the real badge once published. It holds dead still from 19.0 to 20.0 s.
- **Music** is a placeholder bed made with the app's own synth (`tools/make_music.py`: marimba, bells, plucked
  bass, soft kick, a sustained chord layer). It plays C–Am–F–G at 104 BPM: a single low note for the hook, a
  climbing arpeggio for the montage, a held chord under the stamp and a final chord on beat 32. Swap
  `assets/sounds/music.wav` for a licensed track at 96–110 BPM and keep `<audio id="music">`.

## Measured vs looked at

- `npx hyperframes check`: ok (lint, runtime, layout, motion, contrast and craft pass with no errors).
- Looked at: snapshots at every beat and around every cut, frame by frame around the montage releases, the
  `--review` sheets (beats, seams, the 360 px phone sheet), and 18 frames decoded from the final MP4.
- Sound: **measured, not heard.** Final loudness is -14.9 LUFS integrated with a -1.4 dBTP true peak. The
  strong onsets fall on the picture's actions and on the beat grid: flip 4.65, lock ticks 6.67/8.42, again
  8.65, tuck 9.43, montage hits every beat 10.38–14.43, stamp 15.04, flap 16.48, deals 17.91/18.20/18.50.
- Not checked: playback on a real phone under Reels/TikTok UI, and whether the synthesized bed sounds good.

## Weakest shot / with more time

- The bed is synthesized; a real acoustic marimba/pizzicato track would lift the whole film.
- 15.0–16.1 s ("Goal met.") is a still hold on the seal. It is intended as the payoff hold, but a light camera
  push into the wax would add life.
- The phone's own small text (subtitle, labels) is under 28 px. It is product UI, not copy; the titles carry
  the words.

## Warnings kept on purpose

- `line_unread` on the hook letters (they fade while being read by design) and on phone UI text.
- `text_below_floor` on phone UI text; `contrast_aa_failure` on the app's real colours (peach ANSWER label,
  the hint on red during the swipe, the paper THIS over the wall while the card passes).
- `gsap_repeated_fromto_without_baseline`: every timeline uses `defaults: { immediateRender: false }`, and
  the initial states are set with `gsap.set`. Seeking to arbitrary times renders correctly (verified on snapshots).
- `composition_file_too_large` on `film.html`: the phone screen is one stacking context (the tucked card has
  to slide between the stack layers), so the stack and its cards stay in one file.

## Rebuild

```bash
python promo/v01-you-will-forget-this/tools/make_music.py
cd promo/v01-you-will-forget-this
npx hyperframes render --quality delivery --output renders/v01-raw.mp4
python tools/master.py renders/v01-raw.mp4 renders/MemoryCard-V1-YouWillForgetThis-9x16.mp4
```

`tools/mix_preview.py` mixes the `<audio>` tags with ffmpeg to check levels without rendering the picture.
Bernard MT Condensed is gitignored (commercial): copy `app/assets/fonts/BernardMTCondensed.ttf` to
`assets/fonts/` before rendering on another machine.
