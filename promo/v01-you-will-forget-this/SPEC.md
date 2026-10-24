# Video 1 · You will forget this — SPEC

Source brief: `docs/marketing/promo_videos.md` §0 (motion system) and §1 (beat sheet). The owner's beat sheet is
the storyboard; this file turns it into numbers. Everything on the phone is rebuilt from the app's own code
(`app/lib/features/study/*`, `ui/theme.dart`, `ui/shapes.dart`, `ui/icons.dart`, `features/shell/nav_bar.dart`):
same sizes in logical px, same colours, same textures, same fonts, same curves.

```text
GOAL:    a stranger scrolling Reels stops on "YOU WILL FORGET THIS.", learns the one gesture (tap, swipe
         right / left), sees the goal stamped, and leaves with the name "Memory Card".
OUTPUT:  HyperFrames, 1080 x 1920 (9:16 master), 30 fps. 1:1 cut later.
TIME:    20.0 s x 30 = 600 frames. Music 104 BPM: 1 beat = 0.5769 s = 17.31 frames, 1 bar = 2.3077 s.
         Beat n sits at round(n x 17.3077) frames (never accumulated).
LOOK:    paper, not glass.
         ground  paper #F1F1F1 (world behind the phone #EAEAEA), felt.png multiplied at 14 % (300 px tile,
                 x1.7 on screen), window light from the top left: radial white 55 % -> 0 -> black 7 %
                 (the app's _WallPainter), whole-frame grain 2.5 %.
         ink     #333333 (cards, titles); muted #666666; on-ink #F1F1F1; muted on ink #BDBDBD.
         accents blue #80AEFF, peach #FFC680 (answers), red #D35F5F (DONE seal + "forgot" edge only),
                 green #8BD3A0 (remembered edge), category floods: anime #B59CFF, geography #6FD0C8,
                 football #79C267, languages #80AEFF.
         display Bernard MT Condensed (app/assets/fonts), hook 250 px caps, titles 132 px, tracking 0.
         text    Barlow Semi Condensed 600/700 (OFL, @fontsource), sub-lines 54 px.
         phone   neutral body #1B1B1B, 10 logical px bezel, 46 px screen radius, punch-hole 9 px; no brand.
         light   phone shadow 0 40px 80px rgba(0,0,0,.28) + 0 8px 18px rgba(0,0,0,.18) (light from top left).
OBJECTS: the study screen at 390 x 844 logical px: header (logo, "Spanish · Basics", "Today n / 20 · stack
         of 24"), 4 px goal bar, the card 276 x 384 r18 ink #333 with 4 lighter strips above and 3 darker
         below (17 px apart), the corner ears (done / again glyphs), the note chip "Back in 12 cards" + Undo,
         the card-hand nav (Home/Lab/+/Shop/Account, 66 x 98 cards fanned -16 -8 0 8 16 deg about a pivot
         403 px down). A touch dot (44 logical px, ink 30 % + white ring) stands in for the finger.
         The DONE seal: 48-point scallop (r 46/41 of 100), two rings, wax.png at 27 %, "DONE" rotated -12.
         The logo: three cards #686868 0 deg, #4B4B4B 15 deg, #323232 30 deg (icons/logoLightMode.svg).
MOTION:  enter  paper ease cubic-bezier(.2,.8,.2,1); land springy cubic-bezier(.34,1.35,.5,1)
         camera power2.inOut; exit power3.in, 40-50 % shorter than the entrance
         flip   rotateY 0 -> 180, perspective 833 logical px (0.0012), 520 ms springy (the app's _flip)
         swipe  dx -> rot = dx x 0.09 deg, dy = dx^2 x 0.0005, scale = 1 - 0.14 p; commit at 0.6 card
                width; fly-off 230 ms paper ease to w + 160 (the app's _commit), blur 10 px on the flight
         stamp  700 ms keyframes [0: 1.5, -22 deg, 0] [.45: .92, -2, 1] [.7: 1.04, 1] [1: 1, 0] + a
                2-frame shake (8, -6) (-5, 4) px at impact
         titles one stage: blur 8 -> 0 + opacity in 0.16 s; still while read; blur out 0.18 s
SHOTS:   (f = frame at 30 fps)
  0.00-1.73  f0-52    HOOK. Frame 0 = "YOU WILL / FORGET / THIS." filling 80 % of the width on the
                      screen's paper wall (camera at 3.44x, so the wall fills the frame). From 0.70 s the
                      letters of YOU WILL FORGET lose their ink left to right, 40 ms apart, 0.36 s each.
                      Sound: one low marimba C3, room tone.
  1.73-2.45  f52-74   THIS. drops onto the card: the stack rises from below (0.58 s, springy), THIS falls
                      and shrinks into the card's prompt spot, lands on beat 4 (2.31 s): `pop`. Whoosh at 1.80.
  2.45-3.40  f74-102  Camera pulls back 3.44x -> 1.70x (0.95 s power2.inOut): the bezel and the felt world
                      arrive; THIS blur-swaps into "el gato" (label, example, flip hint, Hear it).
  3.46-5.77  f104-173 "Think." (beat 6). Touch dot arcs in, taps on beat 8 (4.62 s): card flips -> peach
                      back "the cat". "Tap." lands on the tap. `flip`.
  5.77-6.92  f173-208 "Knew it? →" (beat 10). Dot drags the card right; right ear swings in; green edge
                      at the 60 % line (`tick` 6.55); release on beat 12 (6.92 s): flies off, `good`.
  6.92-9.23  f208-277 "Not yet? ←" (beat 13). Card 2 "el desayuno" tapped (flip, 7.50), dragged left,
                      red edge (`tick` 8.40), released beat 15 (8.65 s, `again`): it swings back and
                      tucks into the stack, its red edge left sticking out between the bottom layers; chip
                      "Back in 12 cards" counts 1 -> 12. Sub-line "It comes back." (8.65-10.10).
  10.10-14.71 f303-441 MONTAGE. 8 hard cuts, each 1 beat, release on beats 18-25: Tanjiro (anime),
                      Greece (flags), Tottenham (crests), le fromage (French, a left swipe), Nezuko, Japan,
                      Wolves, la fraise. The world floods the deck's category colour on each cut. Header
                      "Today 13..20 / 20" and the goal bar fill one step per swipe. good/easy/again hits.
  14.71-16.10 f441-483 GOAL. World back to paper, screen dims (backdrop 38 %), the DONE seal stamps,
                      impact on beat 26 (15.00 s) + shake, `stamp`, then `fanfare` (15.20). "Goal met."
  16.10-17.31 f483-519 STREAK. A big streak pill in the title band: red flame + split-flap "4" -> "5"
                      on beat 28.5 (16.44 s, `tick`) + "day streak". The flame flares once on the flip.
  17.31-20.00 f519-600 END CARD. A full-bleed paper card slides up over everything (0.55 s, power3.inOut,
                      corners 60 -> 0, `whoosh`); the three logo cards are dealt in on beats 31, 31.5, 32
                      (`card` x3); "Memory Card" wipes in (18.50), "Remember it for good." (18.75),
                      the store pill (18.90). Dead still from 19.00 to 20.00.
BANNED:  dark void; glow/bloom/particles (the green/red swipe edges are a 3 px ink edge + 18 px soft shadow,
         not neon); gradients other than the app's own window light; everything centred AND fading up;
         titles that drift after landing; floating/breathing idles (the app's seal float is dropped);
         click rings; a docked logo; cross-dissolves, glitches, light leaks; any phone brand shape.
QA:      f0 full headline readable (thumbnail); f60 THIS mid-drop over the rising card; f100 phone fully in
         frame; f150 card mid-flip; f200 right ear + green edge; f265 left ear + red edge; f285 tucked card +
         chip "Back in 12"; f320, f370, f420 montage cuts with a flood colour; f452 seal at impact; f500
         streak pill showing 5; f560 logo dealt; f599 final still end card. Every word inside y 250-1500,
         x 0-940.
```
