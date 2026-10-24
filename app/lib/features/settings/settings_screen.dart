import 'dart:convert';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models.dart';
import '../../data/store.dart';
import '../../data/store_scope.dart';
import '../../engine/days.dart';
import '../../services/home_widgets.dart';
import '../../services/reminders.dart';
import '../../ui/fx.dart';
import '../../ui/icons.dart';
import '../../ui/overlays.dart';
import '../../ui/routes.dart';
import '../../ui/textures.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../editor/editor_sheet.dart';
import '../help/help_screen.dart';
import '../lab/memory_lab.dart';
import '../onboarding/onboarding.dart';
import 'texture_pane.dart';
import 'widgets_screen.dart';

/// Settings (canvas Settings.dc.html), plus the engine switches, your data and help.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.scrollToData = false});
  final bool scrollToData;

  static Route<void> route({bool scrollToData = false}) => McPageRoute(builder: (_) => SettingsScreen(scrollToData: scrollToData));

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _dataKey = GlobalKey();
  int _versionTaps = 0;
  bool _lab = false;

  /// 0 General · 1 Texture.
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    if (widget.scrollToData) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _dataKey.currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
      });
    }
  }

  static const _paceNotes = {
    Pace.relaxed: 'New cards join only while you remember about 80% — calm, steady sessions.',
    Pace.balanced: 'New cards join while you remember about 75%. The default.',
    Pace.intense: 'Every card is in the stack from day one. Covers most ground, fails more often.',
  };

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final s = store.settings;
    final mc = Mc.of(context);
    final mq = MediaQuery.of(context);

    Widget section(String title, Widget child, {Key? key}) => Padding(
          key: key,
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(padding: const EdgeInsets.only(bottom: 8), child: SectionLabel(title)),
            child,
          ]),
        );

    Widget panel(List<Widget> children, {EdgeInsets padding = const EdgeInsets.all(14)}) => Container(
          padding: padding,
          foregroundDecoration: texDeco(context, 'tiles', BorderRadius.circular(16)),
          decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(16), boxShadow: mc.e1),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        );

    Widget toggle(String name, String note, bool value, ValueChanged<bool> onChanged, {bool last = false}) => Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: mc.line))),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: T.t(16, w: FontWeight.w700, color: mc.ink)),
                Text(note, style: T.t(14, w: FontWeight.w500, color: mc.muted, height: 1.3)),
              ]),
            ),
            const SizedBox(width: 12),
            McSwitch(value: value, onChanged: onChanged, label: name),
          ]),
        );

    Widget row(String label, VoidCallback onTap, {bool last = false, Color? color, String? hint}) => Pressable(
          onTap: onTap,
          scale: 0.99,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: mc.line))),
            child: Row(children: [
              Expanded(child: Text(label, style: T.t(16, w: FontWeight.w700, color: color ?? mc.ink))),
              if (hint != null) Text(hint, style: T.t(14, w: FontWeight.w600, color: mc.muted)),
              const SizedBox(width: 6),
              McIcon(McIcons.chevron, size: const Size(18, 18), color: color ?? mc.muted),
            ]),
          ),
        );

    final remindAt = '${(s.remindMinutes ~/ 60).toString().padLeft(2, '0')}:${(s.remindMinutes % 60).toString().padLeft(2, '0')}';
    final (title, body) = Reminders.compose(store);

    return Scaffold(
      backgroundColor: mc.canvas,
      body: Wall(child: Column(children: [
        SizedBox(height: mq.padding.top),
        SizedBox(
          height: 76,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 18, 16, 0),
            child: Row(children: [
              IconTap(icon: McIcons.back, size: const Size(26, 26), label: 'Back', onTap: () => Navigator.pop(context)),
              const SizedBox(width: 6),
              Text('Settings', style: T.d(34, color: mc.ink)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
          child: Seg<int>(
            options: const [0, 1],
            value: _tab,
            labelOf: (i) => i == 0 ? 'General' : 'Texture',
            onPick: (i) => setState(() => _tab = i),
          ),
        ),
        if (_tab == 1) const Expanded(child: TexturePane()),
        if (_tab == 0) Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 30 + mq.padding.bottom),
            children: [
              section(
                'Study',
                panel([
                  Text('Reveal the answer by', style: T.t(16, w: FontWeight.w700, color: mc.ink)),
                  const SizedBox(height: 8),
                  Seg<RevealMode>(
                    options: RevealMode.values,
                    value: s.reveal,
                    labelOf: (m) => switch (m) {
                      RevealMode.tap => 'Tap card',
                      RevealMode.icon => 'Tap icon',
                      RevealMode.flip => 'Flip',
                      RevealMode.front => 'Front only',
                    },
                    onPick: (m) => store.updateSettings((x) => x.reveal = m),
                  ),
                  const SizedBox(height: 14),
                  Text('Pictures before the reveal', style: T.t(16, w: FontWeight.w700, color: mc.ink)),
                  const SizedBox(height: 8),
                  Seg<String>(
                    options: const ['blur', 'hide', 'show'],
                    value: s.imageReveal,
                    labelOf: (m) => const {'blur': 'Blur', 'hide': 'Hide', 'show': 'Show'}[m]!,
                    onPick: (m) => store.updateSettings((x) => x.imageReveal = m),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    switch (s.imageReveal) {
                      'blur' => 'Answer pictures peek out blurred behind "Tap to reveal", and any picture you marked '
                          '"Blur until revealed" stays blurred until you reveal it.',
                      'hide' => 'Pictures marked "Blur until revealed" stay invisible until you reveal them, and answers show no peek.',
                      _ => 'Pictures are always shown clearly, nothing waits for the reveal.',
                    },
                    style: T.t(14, w: FontWeight.w500, color: mc.muted, height: 1.35),
                  ),
                  if (s.imageReveal == 'blur') ...[
                    const SizedBox(height: 10),
                    _BlurPreview(sigma: s.blurSigma),
                    Row(children: [
                      Text('Blur', style: T.t(14, w: FontWeight.w600, color: mc.muted)),
                      Expanded(
                        child: McSlider(
                          value: s.blurAmount,
                          divisions: 20,
                          label: 'Blur strength',
                          onChanged: (v) => store.updateSettings((x) => x.blurAmount = double.parse(v.toStringAsFixed(2))),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text('${(s.blurAmount * 100).round()}%',
                            textAlign: TextAlign.right, style: T.t(14, w: FontWeight.w700, color: mc.ink)),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 14),
                  Text('Pace', style: T.t(16, w: FontWeight.w700, color: mc.ink)),
                  const SizedBox(height: 8),
                  Seg<Pace>(
                    options: Pace.values,
                    value: s.pace,
                    fontSize: 15,
                    labelOf: (p) => switch (p) { Pace.relaxed => 'Relaxed', Pace.balanced => 'Balanced', Pace.intense => 'Intense' },
                    onPick: (p) => store.updateSettings((x) => x.pace = p),
                  ),
                  const SizedBox(height: 6),
                  Text(_paceNotes[s.pace]!, style: T.t(14, w: FontWeight.w500, color: mc.muted, height: 1.35)),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Daily goal', style: T.t(16, w: FontWeight.w700, color: mc.ink)),
                        Text('Swipes before the celebration · about ${(s.goal * 6 / 60).ceil()} min',
                            style: T.t(14, w: FontWeight.w500, color: mc.muted)),
                      ]),
                    ),
                    _Stepper(
                      value: s.goal,
                      onChanged: (v) => store.updateSettings((x) => x.goal = v),
                      min: 5,
                      max: 200,
                      step: s.goal < 20 ? 5 : 10,
                    ),
                  ]),
                ]),
              ),
              section(
                'Smart engine',
                panel([
                  toggle('Read how I answer', 'Hesitation, speed and confidence pick Hard, Good or Easy. You can always change it.',
                      s.smartGrading, (v) => store.updateSettings((x) => x.smartGrading = v)),
                  toggle('Show the grade after a swipe', 'A small chip tells you how the answer was read',
                      s.showGrade, (v) => store.updateSettings((x) => x.showGrade = v)),
                  toggle('Let mastered cards rest', 'Cards you know cold skip their turn',
                      s.restMastered, (v) => store.updateSettings((x) => x.restMastered = v)),
                  toggle('Read cards aloud', 'Language decks speak each new card',
                      s.autoSpeak, (v) => store.updateSettings((x) => x.autoSpeak = v)),
                  toggle('Typing: forgive accents', 'é counts as e when you type an answer',
                      s.ignoreAccents, (v) => store.updateSettings((x) => x.ignoreAccents = v), last: true),
                ], padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4)),
              ),
              section(
                'Feel',
                panel([
                  toggle('Sounds', 'Soft clicks and a finish fanfare', s.sounds, (v) {
                    store.updateSettings((x) => x.sounds = v);
                    Fx.i.sounds = v;
                    if (v) Fx.i.pop();
                  }),
                  toggle('Haptics', 'A tick when a swipe locks in', s.haptics, (v) {
                    store.updateSettings((x) => x.haptics = v);
                    Fx.i.haptics = v;
                    if (v) Fx.i.lock();
                  }),
                  toggle('Reduced motion', 'Slides and fades instead of tilts', s.reducedMotion,
                      (v) => store.updateSettings((x) => x.reducedMotion = v), last: true),
                ], padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4)),
              ),
              section(
                'Appearance',
                Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), boxShadow: mc.e1),
                  child: Seg<String>(
                    options: const ['light', 'dark', 'system'],
                    value: s.theme,
                    height: 40,
                    fontSize: 15,
                    background: mc.soft,
                    labelOf: (t) => t[0].toUpperCase() + t.substring(1),
                    onPick: (t) => store.updateSettings((x) => x.theme = t),
                  ),
                ),
              ),
              section(
                'Your name',
                panel([
                  Text('Printed on your membership card', style: T.t(14, w: FontWeight.w500, color: mc.muted)),
                  const SizedBox(height: 8),
                  _NameField(initial: s.name, onSave: (v) => store.updateSettings((x) => x.name = v)),
                ]),
              ),
              section(
                'Reminders',
                panel([
                  Row(children: [
                    Expanded(child: Text('Daily at', style: T.t(16, w: FontWeight.w700, color: mc.ink))),
                    Pressable(
                      onTap: () => _pickTime(context, store),
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: mc.well, borderRadius: BorderRadius.circular(10)),
                        child: Text(remindAt, style: T.d(22, color: mc.ink)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    McSwitch(
                      value: s.remind,
                      label: 'Daily reminder',
                      onChanged: (v) async {
                        if (v && Reminders.i.supported) {
                          final ok = await Reminders.i.requestPermission();
                          if (!ok) {
                            Toaster.i.show('Notifications are off for Memory Card in your phone settings');
                            return;
                          }
                        }
                        store.updateSettings((x) => x.remind = v);
                        await Reminders.i.reschedule(store);
                        if (v) Toaster.i.show('Reminder set for $remindAt');
                      },
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(color: mc.canvas, borderRadius: BorderRadius.circular(12)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      McIcon(McIcons.logo, size: const Size(22, 28), color: mc.ink),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(title, style: T.t(15, w: FontWeight.w700, color: mc.ink, height: 1.3)),
                          Text(body, style: T.t(14, w: FontWeight.w500, color: mc.muted, height: 1.3)),
                        ]),
                      ),
                    ]),
                  ),
                  if (!Reminders.i.supported) ...[
                    const SizedBox(height: 8),
                    Text('Reminders work in the phone app.', style: T.t(13, w: FontWeight.w500, color: mc.muted)),
                  ],
                ]),
              ),
              if (HomeWidgets.i.supported)
                section(
                  'Home screen widgets',
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Container(
                      foregroundDecoration: texDeco(context, 'tiles', BorderRadius.circular(16)),
                      decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(16), boxShadow: mc.e1),
                      clipBehavior: Clip.antiAlias,
                      child: row('Widgets and Quick Settings tile', () => Navigator.of(context).push(WidgetsScreen.route()),
                          hint: '${HomeWidgets.kinds.length} widgets', last: true),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose how they look, preview each one and add it to your home screen.',
                      style: T.t(14, w: FontWeight.w500, color: mc.muted, height: 1.35),
                    ),
                  ]),
                ),
              section(
                'Your data',
                key: _dataKey,
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(
                    foregroundDecoration: texDeco(context, 'tiles', BorderRadius.circular(16)),
                    decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(16), boxShadow: mc.e1),
                    clipBehavior: Clip.antiAlias,
                    child: Column(children: [
                      row('Import cards from CSV', () => showEditor(context, startOnImport: true)),
                      row('Export backup (.json)', () => _export(context, store)),
                      row('Restore a backup', () => _restore(context, store)),
                      row('Export review log (.csv)', () => _exportLog(context, store), hint: '${store.logCount}'),
                      row('Erase everything', () => _erase(context, store), last: true, color: Mc.red),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Text('Everything lives on this phone. Back it up now and then.',
                      style: T.t(14, w: FontWeight.w500, color: mc.muted)),
                ]),
              ),
              section(
                'Help',
                Container(
                  foregroundDecoration: texDeco(context, 'tiles', BorderRadius.circular(16)),
                  decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(16), boxShadow: mc.e1),
                  clipBehavior: Clip.antiAlias,
                  child: Column(children: [
                    row('How Memory Card works', () => Navigator.of(context).push(HelpScreen.route())),
                    row('Memory Lab', () => Navigator.of(context).push(MemoryLab.route())),
                    row('Replay the welcome tour', () => Navigator.of(context).push(McPageRoute(builder: (_) => const Onboarding(replay: true)))),
                    row('Show tips again', () {
                      store.resetCoach();
                      Toaster.i.show('Tips will show again');
                    }, last: true),
                  ]),
                ),
              ),
              if (_lab) section('Lab · developer', _LabPanel(store: store)),
              Row(children: [
                Pressable(
                  onTap: () => _feedback(context),
                  child: Text('Send feedback',
                      style: T.t(16, w: FontWeight.w700, color: mc.ink).copyWith(decoration: TextDecoration.underline)),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    _versionTaps++;
                    if (_versionTaps >= 7 && !_lab) {
                      setState(() => _lab = true);
                      Fx.i.seal();
                      Toaster.i.show('Lab unlocked');
                    }
                  },
                  child: Text('Memory Card 1.0.0', style: T.t(14, w: FontWeight.w600, color: mc.muted)),
                ),
              ]),
            ],
          ),
        ),
      ])),
    );
  }

  Future<void> _pickTime(BuildContext context, AppStore store) async {
    final s = store.settings;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.remindMinutes ~/ 60, minute: s.remindMinutes % 60),
      builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (t == null) return;
    store.updateSettings((x) => x.remindMinutes = t.hour * 60 + t.minute);
    await Reminders.i.reschedule(store);
  }

  Future<void> _export(BuildContext context, AppStore store) async {
    final json = await store.exportBackup();
    final name = 'memory-card-backup-${dayKey(dayNumber(store.now()))}.json';
    final bytes = Uint8List.fromList(utf8.encode(json));
    try {
      final saved = await FilePicker.saveFile(fileName: name, bytes: bytes, mimeType: 'application/json');
      if (saved != null || kIsWeb) Toaster.i.show('Backup saved · ${(bytes.length / 1024).ceil()} KB');
    } catch (_) {
      try {
        await SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes, name: name, mimeType: 'application/json')]));
      } catch (_) {
        Toaster.i.show('Could not save the backup');
      }
    }
  }

  Future<void> _exportLog(BuildContext context, AppStore store) async {
    final logs = await store.logs();
    final lines = ['time,deck,card,grade,mode,elapsed_days,predicted_recall,stability_before,stability_after,difficulty_after,think_ms,verify_ms,reversals,confidence,automatic'];
    for (final l in logs) {
      lines.add([
        DateTime.fromMillisecondsSinceEpoch(l.ts).toIso8601String(),
        l.deckId,
        l.cardId,
        l.grade,
        l.mode,
        l.elapsedDays,
        l.rPred?.toStringAsFixed(4) ?? '',
        l.sBefore?.toStringAsFixed(4) ?? '',
        l.sAfter.toStringAsFixed(4),
        l.dAfter.toStringAsFixed(3),
        l.signals['think'] ?? '',
        l.signals['verify'] ?? '',
        l.signals['rev'] ?? '',
        l.confidence.toStringAsFixed(3),
        l.automatic,
      ].join(','));
    }
    final bytes = Uint8List.fromList(utf8.encode(lines.join('\n')));
    try {
      await FilePicker.saveFile(fileName: 'memory-card-reviews.csv', bytes: bytes, mimeType: 'text/csv');
      Toaster.i.show('${logs.length} reviews exported');
    } catch (_) {
      Toaster.i.show('Could not export the review log');
    }
  }

  Future<void> _restore(BuildContext context, AppStore store) async {
    try {
      final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['json']);
      if (f == null || !context.mounted) return;
      final ok = await confirm(context,
          title: 'Restore this backup?',
          message: 'It replaces everything on this phone with ${f.name}.',
          yes: 'Restore',
          no: 'Cancel');
      if (!ok) return;
      final text = await f.xFile.readAsString();
      await store.importBackup(text);
      Fx.i.seal();
      Toaster.i.show('Backup restored');
    } on FormatException catch (e) {
      Toaster.i.show(e.message);
    } catch (_) {
      Toaster.i.show('Could not read that backup');
    }
  }

  Future<void> _erase(BuildContext context, AppStore store) async {
    final ok = await confirm(context,
        title: 'Erase everything?',
        message: 'Every deck, card, review and streak on this phone is deleted. This cannot be undone.',
        yes: 'Erase',
        no: 'Keep');
    if (!ok || !context.mounted) return;
    final sure = await confirm(context, title: 'Really erase?', message: 'Last chance: export a backup first if you might want it.', yes: 'Erase all');
    if (!sure || !context.mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    await store.eraseAll();
  }

  Future<void> _feedback(BuildContext context) async {
    try {
      await SharePlus.instance.share(ShareParams(
        text: 'Memory Card feedback:\n\n',
        subject: 'Memory Card feedback',
      ));
    } catch (_) {
      Toaster.i.show('Sharing is not available here');
    }
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged, required this.min, required this.max, required this.step});
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    Widget btn(String t, int v, String label) => Pressable(
          label: label,
          haptic: true,
          enabled: v != value,
          onTap: () => onChanged(v),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: mc.well, borderRadius: BorderRadius.circular(12)),
            child: Text(t, style: T.t(22, w: FontWeight.w700, color: mc.ink)),
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      btn('−', (value - step).clamp(min, max), 'Lower daily goal'),
      SizedBox(
        width: 46,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (c, a) => ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: c)),
          child: Text('$value', key: ValueKey(value), textAlign: TextAlign.center, style: T.d(26, color: mc.ink)),
        ),
      ),
      btn('+', (value + step).clamp(min, max), 'Raise daily goal'),
    ]);
  }
}

class _NameField extends StatefulWidget {
  const _NameField({required this.initial, required this.onSave});
  final String initial;
  final ValueChanged<String> onSave;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => McField(
        controller: _c,
        hint: 'Guest Learner',
        display: true,
        size: 22,
        textInputAction: TextInputAction.done,
        onSubmitted: (v) => widget.onSave(v.trim()),
        onChanged: (v) => widget.onSave(v.trim()),
      );
}

/// Developer lab: move the clock to see slipping, warm-up and shields; peek at the engine.
class _LabPanel extends StatelessWidget {
  const _LabPanel({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final e = store.data.engine;
    final b = e.baselines;
    final days = (store.data.clockOffset / msPerDay * 10).round() / 10;
    return Container(
      padding: const EdgeInsets.all(14),
      foregroundDecoration: texDeco(context, 'tiles', BorderRadius.circular(16)),
      decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(16), boxShadow: mc.e1),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Clock ${days == 0 ? '(real time)' : '+$days days'}', style: T.t(16, w: FontWeight.w700, color: mc.ink)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Chip2('+6 hours', onTap: () => store.shiftClock(6 * msPerHour)),
          Chip2('+1 day', onTap: () => store.shiftClock(msPerDay)),
          Chip2('+3 days', onTap: () => store.shiftClock(3 * msPerDay)),
          Chip2('Real time', onTap: () => store.shiftClock(null)),
        ]),
        const SizedBox(height: 12),
        Text(
          'Calibration ×${e.calibration.multiplier.toStringAsFixed(2)} on ${e.calibration.points.length} long-gap reviews\n'
          'Easy at ${e.tuner.easyAt.toStringAsFixed(2)} · Hard below ${e.tuner.hardBelow.toStringAsFixed(2)}\n'
          'Your normal think time ≈ ${(b.expectedThinkMs(12, '') / 1000).toStringAsFixed(1)} s (${b.think.count} answers)\n'
          'Weights: ${e.weights == null ? 'FSRS-6 defaults' : 'personal (trained on ${e.trainedOn})'}',
          style: T.t(14, w: FontWeight.w500, color: mc.muted, height: 1.4),
        ),
      ]),
    );
  }
}


/// A painted landscape under the current blur, so you can see what a picture looks like before the reveal.
class _BlurPreview extends StatelessWidget {
  const _BlurPreview({required this.sigma});
  final double sigma;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 96,
        child: LayoutBuilder(
          builder: (context, box) => Stack(fit: StackFit.expand, children: [
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: sigma * box.maxWidth / 276, sigmaY: sigma * box.maxWidth / 276, tileMode: TileMode.clamp),
              child: const CustomPaint(painter: _ScenePainter()),
            ),
            Positioned(
              right: 8,
              bottom: 6,
              child: Text('what it looks like', style: T.t(12, w: FontWeight.w700, color: Mc.paper)),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  const _ScenePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF80AEFF), Color(0xFFFFC680)])
            .createShader(rect),
    );
    canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.34), size.height * 0.2, Paint()..color = const Color(0xFFFFF3C4));
    final far = Path()
      ..moveTo(0, size.height * 0.72)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.35, size.width * 0.5, size.height * 0.7)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.45, size.width, size.height * 0.66)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(far, Paint()..color = const Color(0xFF8BD3A0));
    final near = Path()
      ..moveTo(0, size.height * 0.88)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.62, size.width, size.height * 0.9)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(near, Paint()..color = const Color(0xFF333333));
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.62), size.height * 0.09, Paint()..color = const Color(0xFFD35F5F));
  }

  @override
  bool shouldRepaint(_ScenePainter old) => false;
}
