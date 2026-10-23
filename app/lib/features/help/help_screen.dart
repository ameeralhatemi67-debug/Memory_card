import 'package:flutter/material.dart';

import '../../ui/icons.dart';
import '../../ui/routes.dart';
import '../../ui/textures.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../onboarding/onboarding.dart';

/// How Memory Card works, in plain words.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static Route<void> route() => McPageRoute(builder: (_) => const HelpScreen());

  static const _topics = <(String, String, String)>[
    (
      'The endless stack',
      McIcons.logo,
      'Every deck is one stack you swipe through. Right: you remembered, the card goes to the back. '
          'Left: not yet, it comes back in 8 to 20 cards. Far enough that the next try is a real recall, '
          'close enough that you meet it again today. The stack never runs out.',
    ),
    (
      'Reveal first, then judge',
      McIcons.eye,
      'Try to remember before you look. Tap the card (or flip it, or tap the eye, as you choose in Settings) '
          'and only then swipe. Trying first is what makes memories stick.',
    ),
    (
      'We read how you answer',
      McIcons.sparkle,
      'A swipe says whether you knew it. How you got there says how well: how long you took compared with '
          'your own normal, whether you hesitated or swung back and forth, how long you checked the answer. '
          'Quick and sure is graded Easy and rests longer; slow or unsure is Hard and returns sooner. A long pause '
          'or a phone call is recognised as an interruption and ignored. Tap the grade on the chip to change it.',
    ),
    (
      'A memory model in the shadow',
      McIcons.chart,
      'Every swipe updates FSRS-6, the most accurate open model of human forgetting. It predicts how likely you '
          'are to remember each card right now. That powers the fan on each deck, memory health, the slipping '
          'counts, reminders and the warm-up after a break. It learns your personal forgetting speed, and in the '
          'Memory Lab you can train it on your own history.',
    ),
    (
      'Pace and the flow guard',
      McIcons.mix,
      'New decks start with 15 cards; more join while you remember about 75 % (Balanced) or 80 % (Relaxed). '
          'Intense puts every card in at once. If a session gets rough, new cards pause until you find your feet; '
          'if you are flying, they arrive faster.',
    ),
    (
      'Daily goal, streak and shields',
      McIcons.done,
      'Reach your daily goal, or see every card that was slipping that morning, and the day counts. Two grace '
          'shields a month cover the days life gets in the way. A new day starts at 4:00, so late nights count '
          'for the evening they belong to.',
    ),
    (
      'Warm-up, resting and tricky cards',
      McIcons.lightbulb,
      'Back after two days or more? Your 20 weakest cards come first. Cards you know cold (recall above 97 %) '
          'rest and skip their turn. A card you keep missing is marked tricky and moves to the end, with an offer '
          'to rewrite it or add a memory hook.',
    ),
    (
      'Daily mix and typing',
      McIcons.keyboard,
      'The Daily mix gathers the slipping cards from all your decks, most urgent first. For any deck you can '
          'type the answer instead of revealing it: close spellings count, accents are forgiven if you like.',
    ),
    (
      'Pictures and layouts',
      McIcons.move,
      'Any side of a card can hold pictures and text. In the card editor tap a side (Front or Back) to arrange it. '
          'Structured gives you a guided shape and lets you crop the picture; Free canvas lets you move, resize and '
          'zoom everything and put words over a picture. PNGs with a see-through background stay see-through. '
          'Settings › Study decides how pictures behave before you reveal them: blurred (how much is up to you), '
          'hidden, or shown.',
    ),
    (
      'Your data stays here',
      McIcons.save,
      'There is no account and no server. Everything is stored on this phone. Export a backup now and then '
          '(Settings › Your data); it restores on any phone. You can also export your full review log.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final mq = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: mc.canvas,
      body: Wall(child: Column(children: [
        SizedBox(height: mq.padding.top),
        SizedBox(
          height: 68,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 12, 0),
            child: Row(children: [
              IconTap(icon: McIcons.back, size: const Size(26, 26), label: 'Back', onTap: () => Navigator.pop(context)),
              const SizedBox(width: 6),
              Expanded(child: Text('How it works', style: T.d(30, color: mc.ink))),
            ]),
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 30 + mq.padding.bottom),
            children: [
              for (var i = 0; i < _topics.length; i++)
                Cascade(
                  index: i,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    foregroundDecoration: texDeco(context, 'tiles', BorderRadius.circular(16)),
                    decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(16), boxShadow: mc.e1),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: mc.ink, borderRadius: BorderRadius.circular(12)),
                        child: Center(child: McIcon(_topics[i].$2, size: const Size(20, 20), color: mc.canvas)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_topics[i].$1, style: T.d(22, color: mc.ink)),
                          const SizedBox(height: 4),
                          Text(_topics[i].$3, style: T.t(15, w: FontWeight.w500, color: mc.muted, height: 1.4)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              const SizedBox(height: 8),
              InkButton('Replay the welcome tour', onTap: () => Navigator.of(context).push(McPageRoute(builder: (_) => const Onboarding(replay: true)))),
            ],
          ),
        ),
      ])),
    );
  }
}
