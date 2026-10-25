import 'package:flutter/material.dart';

import '../../data/store_scope.dart';
import '../../services/reminders.dart';
import '../../services/updates.dart';
import '../../ui/icons.dart';
import '../../ui/overlays.dart';
import '../../ui/routes.dart';
import '../../ui/textures.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../shell/shell.dart';

/// Settings › Updates (nav canvas "Updates · Settings › Updates"): what is installed, a Check now, the two switches,
/// skipped versions, and exactly what is sent.
class UpdatesScreen extends StatelessWidget {
  const UpdatesScreen({super.key});

  static Route<void> route() => McPageRoute(builder: (_) => const UpdatesScreen());

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  /// "today, 09:12" · "yesterday, 09:12" · "3 Nov".
  static String when(int ms, DateTime now) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    if (days <= 0) return 'today, ${two(d.hour)}:${two(d.minute)}';
    if (days == 1) return 'yesterday, ${two(d.hour)}:${two(d.minute)}';
    return '${d.day} ${_months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final s = store.settings;
    final mc = Mc.of(context);
    final mq = MediaQuery.of(context);

    Widget section(String title, Widget child) => Padding(
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

    Widget button(String label, VoidCallback? onTap, {bool primary = true}) => Pressable(
          label: label,
          enabled: onTap != null,
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? 0.5 : 1,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(color: primary ? mc.ink : mc.well, borderRadius: BorderRadius.circular(22)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.t(16, w: FontWeight.w700, color: primary ? mc.onInk : mc.ink))),
              ]),
            ),
          ),
        );

    return Scaffold(
      backgroundColor: mc.canvas,
      body: Wall(
        child: ListenableBuilder(
          listenable: Updates.i,
          builder: (context, _) {
            final u = Updates.i;
            final latest = u.latest;
            final available = u.available && !u.previewing;
            final installed = u.installed.isEmpty ? 'Memory Card' : 'Memory Card ${u.installed}';

            Widget status() {
              if (u.checking) {
                return Row(children: [
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 3, color: mc.ink)),
                  const SizedBox(width: 10),
                  Text('Asking GitHub…', style: T.t(16, w: FontWeight.w600, color: mc.ink)),
                ]);
              }
              if (u.lastOk == false) {
                return Text('Could not reach GitHub. Try again when you are online.', style: T.t(16, w: FontWeight.w600, color: mc.ink, height: 1.3));
              }
              if (available && latest != null) {
                return Row(children: [
                  Container(width: 12, height: 12, decoration: const BoxDecoration(color: Mc.peach, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('${latest.version} is available${latest.megabytes.isEmpty ? '' : ' · ${latest.megabytes}'}',
                        style: T.t(16, w: FontWeight.w700, color: mc.ink)),
                  ),
                ]);
              }
              if (u.skipped && latest != null) {
                return Text('${latest.version} is out, and you skipped it.', style: T.t(16, w: FontWeight.w600, color: mc.ink));
              }
              if (s.updateChecked > 0) {
                return Row(children: [
                  McIcon(McIcons.done, size: const Size(18, 18), color: Mc.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('You are on the newest version · checked ${when(s.updateChecked, DateTime.now())}',
                        style: T.t(16, w: FontWeight.w600, color: mc.ink, height: 1.3)),
                  ),
                ]);
              }
              return Text('Not checked yet.', style: T.t(16, w: FontWeight.w600, color: mc.muted));
            }

            return Column(children: [
              SizedBox(height: mq.padding.top),
              SizedBox(
                height: 76,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 18, 16, 0),
                  child: Row(children: [
                    IconTap(icon: McIcons.back, size: const Size(26, 26), label: 'Back', onTap: () => Navigator.pop(context)),
                    const SizedBox(width: 6),
                    Text('Updates', style: T.d(34, color: mc.ink)),
                  ]),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 30 + mq.padding.bottom),
                  children: [
                    panel([
                      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(installed, style: T.d(34, color: mc.ink, height: 1))),
                      if (u.build.isNotEmpty) Text('build ${u.build}', style: T.t(13, w: FontWeight.w700, color: mc.muted)),
                      const SizedBox(height: 10),
                      ConstrainedBox(constraints: const BoxConstraints(minHeight: 28), child: Align(alignment: Alignment.centerLeft, child: status())),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        button('Check now', u.checking ? null : () => u.check()),
                        if (available)
                          button('See the update card', () {
                            Navigator.pop(context);
                            WidgetsBinding.instance.addPostFrameCallback((_) => Shell.current?.openUpdate());
                          }, primary: false),
                        if (available) button('Skip this version', () => u.skip(), primary: false),
                      ]),
                    ]),
                    const SizedBox(height: 18),
                    section(
                      'How you hear about it',
                      panel([
                        toggle(
                          'Check for updates',
                          'Once a day, when you open the app. It asks GitHub for the newest version number.',
                          s.updateCheck,
                          u.setCheck,
                        ),
                        toggle(
                          'Remind me if I have not updated',
                          'One quiet reminder 4 days after the card first appears, at your reminder time.',
                          s.updateRemind,
                          (v) async {
                            if (v && Reminders.i.supported && !await Reminders.i.requestPermission()) {
                              Toaster.i.show('Notifications are off for Memory Card in your phone settings');
                              return;
                            }
                            u.setRemind(v);
                          },
                          last: true,
                        ),
                      ], padding: const EdgeInsets.fromLTRB(14, 6, 14, 6)),
                    ),
                    if (u.skipped && latest != null)
                      section(
                        'Skipped version',
                        panel([
                          Row(children: [
                            Expanded(child: Text('${latest.version} · you chose Skip this version', style: T.t(16, w: FontWeight.w600, color: mc.ink))),
                            button('Undo', () => u.unskip(), primary: false),
                          ]),
                        ]),
                      ),
                    section(
                      'Installing',
                      panel([
                        Text(
                          'Update now opens GitHub\'s download in your browser. Android asks you to allow that source the first time, '
                          'then you tap Open and Install. Memory Card needs no new permission, and the new version goes over this one: '
                          'your cards, streak and settings stay.',
                          style: T.t(14, w: FontWeight.w500, color: mc.muted, height: 1.4),
                        ),
                      ]),
                    ),
                    section(
                      'What it sends',
                      panel([
                        Text(
                          'One request a day to GitHub, for this project\'s latest release. GitHub sees your IP address, like any website. '
                          'No account, no device ID, nothing from your cards. Nothing downloads without your tap.',
                          style: T.t(14, w: FontWeight.w500, color: mc.muted, height: 1.4),
                        ),
                      ]),
                    ),
                    Pressable(
                      label: 'Preview the update card',
                      onTap: () {
                        u.startPreview();
                        Navigator.pop(context);
                        WidgetsBinding.instance.addPostFrameCallback((_) => Shell.current?.openUpdate());
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('Preview the update card', style: T.t(15, w: FontWeight.w700, color: mc.ink).copyWith(decoration: TextDecoration.underline)),
                      ),
                    ),
                  ],
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
