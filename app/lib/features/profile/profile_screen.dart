import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/store.dart';
import '../../data/store_scope.dart';
import '../../engine/days.dart';
import '../../engine/deck_seals.dart';
import '../../engine/seals.dart';
import '../../ui/deck_look.dart';
import '../../ui/fx.dart';
import '../../ui/icons.dart';
import '../../ui/overlays.dart';
import '../../ui/routes.dart';
import '../../ui/shapes.dart';
import '../../ui/textures.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../settings/settings_screen.dart';
import '../shell/nav_bar.dart';
import '../shell/shell.dart';
import '../study/celebrate.dart';
import '../today/today_screen.dart';

/// Profile, the Account tab (canvas Profile.dc.html): one screen (it scrolls only on short phones). The
/// membership card is a trophy, not a form: its "card number" is your stats, and it flips over to show
/// your activity.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.inShell = false});

  /// Shown as the nav bar's Account tab (no way back, room for the bar), not pushed over the app.
  final bool inShell;

  static Route<void> route() => McPageRoute(builder: (_) => const ProfileScreen());

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  bool _back = false;

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  void _toggle() {
    Fx.i.reveal();
    setState(() => _back = !_back);
    _flip.animateTo(_back ? 1 : 0, curve: const Cubic(0.3, 1.25, 0.4, 1));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final mc = Mc.of(context);
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardH = math.min(244.0, (w - 28) * 0.63);
    // In the nav bar the page ends above it; on short phones it scrolls instead of overlapping.
    final bottom = mq.padding.bottom + (widget.inShell ? NavBar.height : 0) + 24;
    final card = SizedBox(
      height: cardH,
      child: GestureDetector(
        onTap: _toggle,
        child: AnimatedBuilder(
          animation: _flip,
          builder: (context, _) {
            final a = _flip.value * math.pi;
            final showBack = a > math.pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0009)
                ..rotateY(showBack ? a - math.pi : a),
              child: showBack ? _CardBack(store: store) : _CardFront(store: store),
            );
          },
        ),
      ),
    );
    final signIn = Column(children: [
      Text.rich(
        TextSpan(children: [
          TextSpan(text: 'Back up your progress? ', style: T.d(17, color: mc.muted)),
          WidgetSpan(
            child: GestureDetector(
              onTap: () => _signIn(context),
              child: Text('Sign in', style: T.d(17, color: mc.ink).copyWith(decoration: TextDecoration.underline)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _Badge(shape: PolarShape.badgeScallop, label: 'Sign in with Google', icon: McIcons.google, iconSize: const Size(34, 34), onTap: () => _signIn(context)),
        const SizedBox(width: 30),
        _Badge(shape: PolarShape.badgeBurst, label: 'Create a Memory Card account', icon: McIcons.logo, iconSize: const Size(27, 34), tint: true, onTap: () => _signIn(context)),
        const SizedBox(width: 30),
        _Badge(shape: PolarShape.badgeSquircle, label: 'Sign in with Apple', icon: McIcons.apple, iconSize: const Size(28, 34), tint: true, onTap: () => _signIn(context)),
      ]),
      const SizedBox(height: 14),
      Text('Optional. Everything works offline without an account.',
          textAlign: TextAlign.center, style: T.t(14, w: FontWeight.w500, color: mc.muted)),
    ]);
    return Scaffold(
      backgroundColor: mc.canvas,
      body: Wall(child: Stack(children: [
        // The corner of a huge card resting on the page: thickness band, then the face.
        Positioned(
          left: w + 10,
          top: -350,
          child: Transform.rotate(
            alignment: Alignment.bottomLeft,
            angle: -math.pi / 4,
            child: Container(width: 640, height: 640, decoration: BoxDecoration(color: mc.sash, borderRadius: BorderRadius.circular(56))),
          ),
        ),
        Positioned(
          left: w + 10,
          top: -368,
          child: Transform.rotate(
            alignment: Alignment.bottomLeft,
            angle: -math.pi / 4,
            child: Container(
              width: 640,
              height: 640,
              decoration: BoxDecoration(color: mc.cardFace, borderRadius: BorderRadius.circular(56), boxShadow: mc.faceShadow),
            ),
          ),
        ),
        Positioned.fill(
          child: LayoutBuilder(builder: (context, box) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: EdgeInsets.only(top: mq.padding.top + 92, bottom: bottom),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 22), child: _Greeting(store: store)),
                      const SizedBox(height: 24),
                      // On a tall phone the card sits a little above the middle, as on the canvas.
                      const Spacer(flex: 2),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: card),
                      const SizedBox(height: 12),
                      Text(_back ? 'Tap the card to flip it back' : 'Tap the card to see your activity',
                          textAlign: TextAlign.center, style: T.t(14, w: FontWeight.w600, color: mc.muted)),
                      const SizedBox(height: 12),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _SealsRow(store: store)),
                      const SizedBox(height: 24),
                      const Spacer(flex: 3),
                      signIn,
                    ]),
                  ),
                ),
              ),
            );
          }),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: mq.padding.top,
          child: SizedBox(
            height: 76,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 12, 0),
              child: Row(children: [
                widget.inShell
                    ? IconTap(icon: McIcons.logo, label: 'Open folders', onTap: () => Shell.of(context).openDrawer())
                    : IconTap(icon: McIcons.logo, label: 'Back to decks', onTap: () => Navigator.pop(context)),
                if (widget.inShell) ...[
                  const SizedBox(width: 12),
                  Text('Account', style: T.d(26, color: mc.ink)),
                ],
                const Spacer(),
                IconTap(
                  icon: McIcons.sun,
                  label: dark ? 'Switch to light mode' : 'Switch to dark mode',
                  size: const Size(36, 36),
                  onTap: () {
                    Fx.i.tap();
                    store.updateSettings((s) => s.theme = dark ? 'light' : 'dark');
                  },
                ),
                if (widget.inShell)
                  IconTap(
                    icon: McIcons.gear,
                    label: 'Settings',
                    size: const Size(28, 32),
                    onTap: () => Navigator.of(context, rootNavigator: true).push(SettingsScreen.route()),
                  ),
              ]),
            ),
          ),
        ),
      ])),
    );
  }

  void _signIn(BuildContext context) {
    final mc = Mc.of(context);
    showMcDialog(
      context,
      builder: (ctx) => DialogCard(children: [
        Center(child: WaxSeal(size: 72, color: Mc.blue, child: McIcon(McIcons.logo, size: const Size(22, 28), color: Mc.graphite))),
        const SizedBox(height: 14),
        Text('Accounts come with sync', textAlign: TextAlign.center, style: T.d(30, color: mc.ink, height: 1.05)),
        const SizedBox(height: 8),
        Text(
          'This version keeps everything on your phone: no account, no servers. To keep your progress safe, '
          'export a backup now and then. You can restore it on any phone.',
          textAlign: TextAlign.center,
          style: T.t(16, color: mc.muted, height: 1.35),
        ),
        const SizedBox(height: 18),
        InkButton('Back up now', height: 52, onTap: () {
          Navigator.pop(ctx);
          Navigator.of(context, rootNavigator: true).push(SettingsScreen.route(scrollToData: true));
        }),
        const SizedBox(height: 10),
        SoftButton('Not now', onTap: () => Navigator.pop(ctx)),
      ]),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final hour = DateTime.now().hour;
    final part = hour < 5 ? 'Late night' : hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';
    final name = store.settings.name.trim();
    final t = store.today;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(name.isEmpty ? part : '$part, $name', style: T.d(34, color: mc.ink)),
      const SizedBox(height: 4),
      GestureDetector(
        onTap: () => Navigator.of(context, rootNavigator: true).push(TodayScreen.route()),
        child: Text(
          t.goalHit ? "Today's goal is done. Anything more is a bonus." : '${t.done} of ${store.settings.goal} cards today ›',
          style: T.t(16, w: FontWeight.w600, color: mc.muted),
        ),
      ),
    ]);
  }
}

Color _tierColor(String t) => switch (t) {
      'Platinum' => const Color(0xFFBFE3EC),
      'Gold' => const Color(0xFFE9C46A),
      'Silver' => const Color(0xFFCDD2D8),
      _ => Mc.tier,
    };

class _CardFront extends StatelessWidget {
  const _CardFront({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final lib = store.libraryStats();
    final p = store.data.profile;
    final streak = store.engine.liveStreak();
    final tier = tierFor(lib.mastered, p.bestStreak);
    final since = DateTime.fromMillisecondsSinceEpoch(p.since).year;
    String four(int v) => v.clamp(0, 9999).toString().padLeft(4, '0');
    final digits = [
      (four(lib.mastered), 'mastered'),
      (four(streak), 'streak'),
      (lib.health == null ? '----' : four((lib.health! * 100).round()), 'health %'),
      ('$since', 'since'),
    ];
    final name = store.settings.name.trim().isEmpty ? 'Guest Learner' : store.settings.name.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      foregroundDecoration: texDeco(context, 'cards', BorderRadius.circular(18)),
      decoration: BoxDecoration(
        color: mc.ink,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: mc.dark ? 0.32 : 0.24), blurRadius: mc.dark ? 48 : 36, offset: const Offset(0, 16))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _tierColor(tier), borderRadius: BorderRadius.circular(13)),
            child: Text('$tier tier'.toUpperCase(), style: T.caps(12, color: Mc.graphite)),
          ),
          const Spacer(),
          McIcon(McIcons.logo, size: const Size(34, 44), color: mc.onInk),
        ]),
        const Spacer(),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(name, style: T.d(36, color: mc.onInk))),
        const SizedBox(height: 10),
        Row(children: [
          for (final (v, label) in digits)
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FittedBox(fit: BoxFit.scaleDown, child: Text(v, style: T.d(32, color: mc.digits, spacing: 1))),
                const SizedBox(height: 3),
                Text(label.toUpperCase(), maxLines: 1, style: T.caps(10.5, color: mc.mutedOnInk, spacing: 1)),
              ]),
            ),
        ]),
      ]),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final p = store.data.profile;
    final lib = store.libraryStats();
    final streak = store.engine.liveStreak();
    final today = store.today.day;
    final history = p.history;
    final felt = _feltSuccess(store);
    // 35 days, oldest first, aligned so each column is a weekday.
    final start = today - 34;
    final cells = [
      for (var d = start; d <= today; d++)
        () {
          final r = history[d];
          final n = r?.swipes ?? 0;
          final level = n == 0 ? 0 : n < 10 ? 1 : n < 25 ? 2 : n < 45 ? 3 : 4;
          return (level, d == today);
        }(),
    ];
    return Container(
      foregroundDecoration: texDeco(context, 'cards', BorderRadius.circular(18)),
      decoration: BoxDecoration(
        color: mc.ink,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: mc.dark ? 0.32 : 0.24), blurRadius: mc.dark ? 48 : 36, offset: const Offset(0, 16))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned(left: 0, right: 0, top: 20, height: 34, child: ColoredBox(color: mc.stripe)),
        Positioned(
          left: 20,
          top: 66,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('LAST 5 WEEKS', style: T.caps(11, color: mc.mutedOnInk)),
            const SizedBox(height: 8),
            SizedBox(
              width: 7 * 14 + 6 * 4,
              child: Wrap(spacing: 4, runSpacing: 4, children: [
                for (final (level, isToday) in cells)
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: mc.heat[level],
                      borderRadius: BorderRadius.circular(4),
                      border: isToday ? Border.all(color: Mc.red, width: 1.5) : null,
                    ),
                  ),
              ]),
            ),
          ]),
        ),
        Positioned(
          left: 172,
          right: 18,
          top: 64,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const SizedBox(width: 18, height: 21, child: CustomPaint(painter: FlamePainter())),
              const SizedBox(width: 8),
              Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text('$streak-day streak', style: T.d(24, color: mc.onInk)))),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              for (var i = 0; i < 2; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: SizedBox(width: 13, height: 15, child: CustomPaint(painter: ShieldPainter(used: i >= p.shields))),
                ),
              Text('${p.shields} ${p.shields == 1 ? 'shield' : 'shields'} left', style: T.t(12, w: FontWeight.w600, color: mc.mutedOnInk)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              for (final (v, label) in [
                ('${lib.mastered}', 'cards mastered'),
                (lib.health == null ? '—' : '${(lib.health! * 100).round()}%', 'memory health'),
                (felt == null ? '—' : '${(felt * 100).round()}%', 'felt success'),
              ])
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    FittedBox(fit: BoxFit.scaleDown, child: Text(v, style: T.d(24, color: mc.onInk))),
                    const SizedBox(height: 2),
                    Text(label, style: T.t(11, w: FontWeight.w600, color: mc.mutedOnInk, height: 1.15)),
                  ]),
                ),
            ]),
          ]),
        ),
        Positioned(
          right: 18,
          bottom: 14,
          child: Text('Member since ${DateTime.fromMillisecondsSinceEpoch(p.since).year} · best streak ${p.bestStreak}',
              style: T.t(11, w: FontWeight.w600, color: mc.mutedOnInk)),
        ),
      ]),
    );
  }

  static double? _feltSuccess(AppStore store) {
    var n = 0, ok = 0;
    final today = store.today.day;
    for (var d = today - 13; d <= today; d++) {
      final r = store.data.profile.history[d];
      if (r == null) continue;
      n += r.swipes;
      ok += r.ok;
    }
    return n == 0 ? null : ok / n;
  }
}

class _SealsRow extends StatelessWidget {
  const _SealsRow({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final earned = Seals.all.where((s) => store.data.profile.seals.containsKey(s.id)).toList();
    final deckSeals = store.data.decks.values.fold(0, (n, d) => n + d.sealsEarned.length);
    return Pressable(
      onTap: () => showSealGallery(context, store),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        foregroundDecoration: texDeco(context, 'tiles', BorderRadius.circular(16)),
        decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(16), boxShadow: mc.e1),
        child: Row(children: [
          if (earned.isEmpty)
            WaxSeal(size: 34, color: mc.line)
          else
            // The latest few, side by side so every mark stays readable.
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < math.min(earned.length, 4); i++) ...[
                if (i > 0) const SizedBox(width: 4),
                SealBadge(def: earned[earned.length - 1 - i], size: 32),
              ],
            ]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              earned.isEmpty
                  ? 'Seals · earn your first with one swipe'
                  : deckSeals > 0
                      ? 'Seals · ${earned.length + deckSeals} pressed'
                      : 'Seals · ${earned.length} of ${Seals.all.length}',
              style: T.t(15, w: FontWeight.w700, color: mc.ink),
            ),
          ),
          McIcon(McIcons.chevron, size: const Size(18, 18), color: mc.muted),
        ]),
      ),
    );
  }
}

Future<void> showSealGallery(BuildContext context, AppStore store) {
  return showMcSheet(context, builder: (ctx) {
    final mc = Mc.of(ctx);
    final seals = store.data.profile.seals;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + MediaQuery.of(ctx).padding.bottom),
      children: [
        Text('Seals', style: T.d(34, color: mc.ink)),
        const SizedBox(height: 4),
        Text('Pressed into your card as you go. ${seals.length} of ${Seals.all.length}.',
            style: T.t(15, w: FontWeight.w600, color: mc.muted)),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 10,
          childAspectRatio: 0.78,
          children: [
            for (final s in Seals.all)
              Column(children: [
                Opacity(opacity: seals.containsKey(s.id) ? 1 : 0.5, child: SealBadge(def: s, size: 68, earned: seals.containsKey(s.id))),
                const SizedBox(height: 6),
                Text(s.title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: T.t(14, w: FontWeight.w700, color: seals.containsKey(s.id) ? mc.ink : mc.muted)),
                Text(seals.containsKey(s.id) ? dayKey(seals[s.id]!) : s.note,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: T.t(11.5, w: FontWeight.w500, color: mc.muted, height: 1.2)),
              ]),
          ],
        ),
        // Every deck in the library that has seals of its own (yours, or from the shop).
        for (final d in [...store.data.activeDecks, ...?store.data.folderById(Folder.archiveId)?.deckIds.map((id) => store.data.decks[id]).whereType<Deck>()])
          if (store.sealsOf(d).isNotEmpty) ...[
            const SizedBox(height: 22),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.d(22, color: mc.ink))),
              Text('${d.sealsEarned.length} of ${store.sealsOf(d).length}', style: T.t(13, w: FontWeight.w600, color: mc.muted)),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 14, children: [
              for (final s in store.sealsOf(d))
                SizedBox(
                  width: 104,
                  child: Column(children: [
                    SizedBox(
                      height: 68,
                      child: Center(
                        child: Opacity(
                          opacity: d.sealsEarned.containsKey(s.id) ? 1 : 0.5,
                          child: DeckSealBadge(seal: s, size: s.wide ? 60 : 68, earned: d.sealsEarned.containsKey(s.id)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(s.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.t(14, w: FontWeight.w700, color: d.sealsEarned.containsKey(s.id) ? mc.ink : mc.muted)),
                    Text(
                        d.sealsEarned.containsKey(s.id)
                            ? dayKey(dayNumber(d.sealsEarned[s.id]!))
                            : DeckMilestones.of(s.when).label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: T.t(11.5, w: FontWeight.w500, color: mc.muted, height: 1.2)),
                  ]),
                ),
            ]),
          ],
      ],
    );
  });
}

class _Badge extends StatelessWidget {
  const _Badge({required this.shape, required this.label, required this.icon, required this.iconSize, required this.onTap, this.tint = false});
  final PolarShape shape;
  final String label;
  final String icon;
  final Size iconSize;
  final VoidCallback onTap;
  final bool tint;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Pressable(
      label: label,
      scale: 0.92,
      onTap: onTap,
      child: SizedBox(
        width: 84,
        height: 84,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(
            size: const Size(84, 84),
            painter: PolarPainter(shape, mc.badge, shadow: [
              BoxShadow(color: Colors.black.withValues(alpha: mc.dark ? 0.3 : 0.25), blurRadius: mc.dark ? 16 : 10, offset: const Offset(0, 6)),
            ]),
          ),
          McIcon(icon, size: iconSize, color: tint ? mc.badgeInk : null),
        ]),
      ),
    );
  }
}
