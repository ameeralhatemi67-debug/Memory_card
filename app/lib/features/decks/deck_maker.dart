import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models.dart';
import '../../data/store.dart';
import '../../data/store_scope.dart';
import '../../engine/deck_seals.dart';
import '../../ui/deck_look.dart';
import '../../ui/fx.dart';
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../../ui/overlays.dart';
import '../../ui/textures.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../editor/editor_sheet.dart' show deckLanguages;
import '../layout/layout_face.dart' show cardImage, measureAspect;
import '../layout/pick_picture.dart';
import '../study/celebrate.dart' show StampedDeckSeal;
import 'deck_row.dart';

/// The deck maker: a new deck (in [folderId]) or an existing one ([deckId]): its name, its language, its
/// look (a picture skin, previewed live on the deck's own bar) and its seals. Returns the deck's id, or
/// null if it was closed without saving.
Future<String?> openDeckMaker(BuildContext context, {String? folderId, String? deckId}) =>
    showMcSheet<String>(context, top: 72, builder: (ctx) => DeckMaker(folderId: folderId, deckId: deckId));

enum _Look { shop, plain, picture }

class DeckMaker extends StatefulWidget {
  const DeckMaker({super.key, this.folderId, this.deckId});
  final String? folderId;
  final String? deckId;

  @override
  State<DeckMaker> createState() => _DeckMakerState();
}

class _DeckMakerState extends State<DeckMaker> {
  late final AppStore store = context.storeRead;
  final _name = TextEditingController();
  String? _lang;
  bool _code = false;
  _Look _look = _Look.plain;

  /// The picture skin being made (kept while another look is tried).
  DeckSkin? _skin;

  /// Its width ÷ height, so the picture can follow the finger exactly.
  double? _aspect;
  List<DeckSeal> _seals = [];

  Deck? get _deck => widget.deckId == null ? null : store.data.decks[widget.deckId];
  DeckSkin? get _shopSkin => _deck == null ? null : store.catalogOf(_deck!)?.skin;

  /// A deck you made yourself (not one from the shop): its seals are yours to design.
  bool get _own => _deck?.catalogId == null;

  DeckSkin? get _shown => switch (_look) {
        _Look.shop => _shopSkin,
        _Look.picture => _skin,
        _Look.plain => null,
      };

  @override
  void initState() {
    super.initState();
    final d = _deck;
    if (d != null) {
      _name.text = d.name;
      _lang = d.lang;
      _code = d.kind == 'code';
      final own = d.skin;
      if (own != null && !own.plain) {
        _look = _Look.picture;
        _skin = own.copy();
        measureAspect(own.src).then((a) {
          if (mounted) setState(() => _aspect = a);
        });
      } else {
        _look = own == null && _shopSkin != null ? _Look.shop : _Look.plain;
      }
      _seals = [for (final s in d.seals) s.copy()];
    }
    _name.addListener(_typed);
  }

  void _typed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _name.removeListener(_typed);
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickSkin() async {
    FocusScope.of(context).unfocus();
    final p = await pickPicture(context);
    if (p == null || !mounted) return;
    Fx.i.pop();
    setState(() {
      _skin = DeckSkin(src: p.src, shade: _skin?.shade ?? 0.55, light: _skin?.light ?? true);
      _aspect = p.aspect;
      _look = _Look.picture;
    });
  }

  /// Dragging the preview moves the picture under the bar (the focal point follows the finger 1:1).
  void _pan(DragUpdateDetails d, double w, double h) {
    final skin = _skin, a = _aspect;
    if (_look != _Look.picture || skin == null || a == null) return;
    final sw = math.max(w, h * a), sh = math.max(h, w / a);
    final ox = sw * skin.zoom - w, oy = sh * skin.zoom - h;
    setState(() {
      if (ox > 1) skin.x = (skin.x - d.delta.dx / ox).clamp(0.0, 1.0);
      if (oy > 1) skin.y = (skin.y - d.delta.dy / oy).clamp(0.0, 1.0);
    });
  }

  Future<void> _editSeal(DeckSeal? seal) async {
    FocusScope.of(context).unfocus();
    final taken = {for (final s in _seals) if (s.id != seal?.id) s.when};
    final r = await openSealMaker(context, seal: seal, taken: taken, deckName: _name.text.trim());
    if (r == null || !mounted) return;
    setState(() {
      final i = seal == null ? -1 : _seals.indexWhere((s) => s.id == seal.id);
      if (r == 'delete') {
        if (i >= 0) _seals.removeAt(i);
      } else if (r is DeckSeal) {
        i >= 0 ? _seals[i] = r : _seals.add(r);
      }
    });
  }

  void _save() {
    final n = _name.text.trim();
    if (n.isEmpty) {
      Fx.i.warn();
      Toaster.i.show('Give the deck a name');
      return;
    }
    // Plain on a shop deck that has its own skin is a choice to remember; elsewhere it is the default.
    final skin = switch (_look) {
      _Look.picture => _skin,
      _Look.plain => _shopSkin != null ? DeckSkin.none() : null,
      _Look.shop => null,
    };
    final category = _lang != null ? 'lang' : (_code ? 'code' : 'custom');
    final d = _deck;
    if (d == null) {
      final created = store.createDeck(
        name: n,
        folderId: widget.folderId ?? store.currentFolder?.id ?? store.createFolder('Library').id,
        lang: _lang,
        kind: _code ? 'code' : 'text',
        category: category,
        skin: skin,
        seals: _seals,
      );
      Fx.i.pop();
      Navigator.pop(context, created.id);
      return;
    }
    d.name = n;
    if (_own) {
      d.lang = _lang;
      d.kind = _code ? 'code' : 'text';
      d.category = category;
    }
    store.saveLook(d.id, skin: skin, seals: _own ? _seals : null);
    Fx.i.pop();
    Navigator.pop(context, d.id);
    Toaster.i.show('Saved ${d.name}');
  }

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final bottom = MediaQuery.of(context).padding.bottom;
    final deck = _deck;
    final stats = deck == null ? null : store.stats(deck);
    final name = _name.text.trim();
    final skin = _shown;
    final shopSeals = deck == null ? const <DeckSeal>[] : (store.catalogOf(deck)?.seals ?? const <DeckSeal>[]);
    final looks = [if (_shopSkin != null) _Look.shop, _Look.plain, _Look.picture];

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 2, 20, 16 + bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Text(deck == null ? 'New deck' : 'Your deck', style: T.d(32, color: mc.ink)),
              const SizedBox(height: 14),
              // The live preview: exactly the bar the deck gets in your library.
              LayoutBuilder(builder: (context, box) {
                final w = math.min(box.maxWidth, 520.0);
                return Center(
                  child: GestureDetector(
                    onPanUpdate: (d) => _pan(d, w, 72),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: McCurves.out,
                      child: DeckBarFace(
                        key: ValueKey('${_look.name}-${skin?.src}'),
                        id: deck?.id ?? 'new-deck',
                        name: name.isEmpty ? 'Your deck' : name,
                        meta: stats == null ? 'New deck · no cards yet' : deckMetaOf(stats),
                        steps: stats?.steps ?? 0,
                        pinned: deck?.pinned ?? false,
                        skin: skin,
                        width: w,
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              Text(
                _look == _Look.picture ? 'Drag the picture to place it' : 'This is how it sits in your library',
                textAlign: TextAlign.center,
                style: T.t(13, w: FontWeight.w600, color: mc.muted),
              ),
              const SizedBox(height: 18),
              FieldLabel('Name', child: McField(controller: _name, hint: 'German · Kitchen', display: true, autofocus: deck == null)),
              if (_own) ...[
                const SizedBox(height: 14),
                Text('Read the front aloud in', style: T.t(14, w: FontWeight.w700, color: mc.muted)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final (l, label) in deckLanguages)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Chip2(label, selected: _lang == l, height: 32, onTap: () => setState(() => _lang = l)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: Text('Fronts are code', style: T.t(16, w: FontWeight.w700, color: mc.ink))),
                  McSwitch(value: _code, onChanged: (v) => setState(() => _code = v), label: 'Fronts are code'),
                ]),
              ],
              const SizedBox(height: 24),
              const SectionLabel('Look'),
              const SizedBox(height: 8),
              Seg<_Look>(
                options: looks,
                value: _look,
                height: 38,
                fontSize: 15,
                labelOf: (v) => switch (v) { _Look.shop => 'Shop', _Look.plain => 'Plain', _Look.picture => 'Picture' },
                onPick: (v) {
                  if (v == _Look.picture && _skin == null) {
                    _pickSkin();
                    return;
                  }
                  setState(() => _look = v);
                },
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: McCurves.out,
                alignment: Alignment.topCenter,
                child: _look == _Look.picture && _skin != null ? _pictureControls(mc, _skin!) : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: 26),
              const SectionLabel('Seals'),
              const SizedBox(height: 4),
              Text(
                _own
                    ? 'Design seals for this deck: each is pressed when the deck reaches its milestone.'
                    : 'Seals that come with this deck from the shop.',
                style: T.t(14, w: FontWeight.w500, color: mc.muted, height: 1.3),
              ),
              const SizedBox(height: 12),
              if (!_own && shopSeals.isEmpty)
                Text('This shop deck has no seals of its own.', style: T.t(14, w: FontWeight.w600, color: mc.muted))
              else
                Wrap(spacing: 12, runSpacing: 14, children: [
                  if (!_own)
                    for (final s in shopSeals) _SealTile(seal: s, earned: deck?.sealsEarned.containsKey(s.id) ?? false),
                  if (_own) ...[
                    for (final s in _seals) _SealTile(seal: s, earned: true, onTap: () => _editSeal(s)),
                    if (_seals.length < DeckMilestones.all.length) _AddSealTile(onTap: () => _editSeal(null)),
                  ],
                ]),
              const SizedBox(height: 12),
            ],
          ),
        ),
        const SizedBox(height: 10),
        InkButton(deck == null ? 'Create deck' : 'Save', height: 54, size: 23, onTap: _save),
      ]),
    );
  }

  Widget _pictureControls(Mc mc, DeckSkin skin) {
    Widget row(String label, Widget child) => Row(children: [
          SizedBox(width: 62, child: Text(label, style: T.t(14, w: FontWeight.w700, color: mc.muted))),
          Expanded(child: child),
        ]);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: SoftButton('Change picture',
                height: 46, icon: McIcon(McIcons.image, size: const Size(18, 18), color: mc.ink), onTap: _pickSkin),
          ),
          const SizedBox(width: 8),
          SoftButton('Remove', height: 46, onTap: () => setState(() {
                _skin = null;
                _look = _shopSkin != null ? _Look.shop : _Look.plain;
              })),
        ]),
        const SizedBox(height: 6),
        row('Zoom', McSlider(value: skin.zoom, min: 1, max: 3, label: 'Zoom', onChanged: (v) => setState(() => skin.zoom = v))),
        row('Shade', McSlider(value: skin.shade, label: 'Shade', onChanged: (v) => setState(() => skin.shade = v))),
        const SizedBox(height: 4),
        row(
          'Text',
          Seg<bool>(
            options: const [true, false],
            value: skin.light,
            height: 34,
            labelOf: (v) => v ? 'Light on dark' : 'Dark on light',
            onPick: (v) => setState(() => skin.light = v),
          ),
        ),
      ]),
    );
  }
}

/// A seal with its name under it (the deck maker's row of seals).
class _SealTile extends StatelessWidget {
  const _SealTile({required this.seal, required this.earned, this.onTap});
  final DeckSeal seal;
  final bool earned;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final child = SizedBox(
      width: 96,
      child: Column(children: [
        SizedBox(
          height: 64,
          child: Center(
            child: Opacity(opacity: earned ? 1 : 0.55, child: DeckSealBadge(seal: seal, size: seal.wide ? 58 : 64, earned: earned)),
          ),
        ),
        const SizedBox(height: 6),
        Text(seal.title.isEmpty ? DeckMilestones.of(seal.when).label : seal.title,
            maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: T.t(13, w: FontWeight.w700, color: mc.ink)),
        Text(DeckMilestones.of(seal.when).label,
            maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: T.t(11.5, w: FontWeight.w600, color: mc.muted)),
      ]),
    );
    return onTap == null ? child : Pressable(label: 'Edit seal ${seal.title}', onTap: onTap, child: child);
  }
}

class _AddSealTile extends StatelessWidget {
  const _AddSealTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Pressable(
      label: 'Design a seal',
      haptic: true,
      onTap: onTap,
      child: SizedBox(
        width: 96,
        child: Column(children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: mc.soft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: mc.dash, width: 2),
            ),
            child: Center(child: McIcon(McIcons.plus, size: const Size(22, 22), color: mc.ink)),
          ),
          const SizedBox(height: 6),
          Text('New seal', style: T.t(13, w: FontWeight.w700, color: mc.ink)),
          Text('square or wide', style: T.t(11.5, w: FontWeight.w600, color: mc.muted)),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- the seal maker

/// Designs one seal: shape, wax colour, stamped text, a picture pressed in, its name and its milestone
/// ([taken] are the milestones other seals of the deck already use). Returns the seal, 'delete', or null.
Future<Object?> openSealMaker(BuildContext context, {DeckSeal? seal, Set<String> taken = const {}, String deckName = ''}) =>
    showMcSheet<Object>(context, top: 72, builder: (ctx) => _SealMaker(seal: seal, taken: taken, deckName: deckName));

class _SealMaker extends StatefulWidget {
  const _SealMaker({this.seal, required this.taken, required this.deckName});
  final DeckSeal? seal;
  final Set<String> taken;
  final String deckName;

  @override
  State<_SealMaker> createState() => _SealMakerState();
}

class _SealMakerState extends State<_SealMaker> {
  late final DeckSeal _s = widget.seal?.copy() ??
      DeckSeal(
        id: uid('seal'),
        title: '',
        when: DeckMilestones.all.firstWhere((m) => !widget.taken.contains(m.id), orElse: () => DeckMilestones.all.last).id,
        text: widget.deckName.isEmpty ? 'MINE' : widget.deckName.split(RegExp(r'[\s·]+')).first.toUpperCase(),
      );
  late final _title = TextEditingController(text: _s.title);
  late final _text = TextEditingController(text: _s.text);

  /// Replays the stamp when the seal's look changes.
  int _stamp = 0;

  /// The picture has see-through parts (null: not known, an older picture).
  bool? _alpha;

  @override
  void initState() {
    super.initState();
    if (_s.text.length > 12) _s.text = _s.text.substring(0, 12);
    _text.text = _s.text;
    _text.addListener(() => setState(() => _s.text = _text.text));
    _title.addListener(() => setState(() => _s.title = _title.text));
  }

  @override
  void dispose() {
    _title.dispose();
    _text.dispose();
    super.dispose();
  }

  void _restamp(VoidCallback change) {
    setState(() {
      change();
      _stamp++;
    });
  }

  Future<void> _pickImage() async {
    FocusScope.of(context).unfocus();
    final p = await pickPicture(context);
    if (p == null || !mounted) return;
    _restamp(() {
      _s.image = p.src;
      _alpha = p.alpha;
      // A photo with no see-through parts would press in as a solid block: it keeps its colours.
      if (!p.alpha) _s.art = 'color';
    });
    if (!p.alpha) Toaster.i.show('No see-through background, so it keeps its colours');
  }

  void _save() {
    if (_s.text.trim().isEmpty && !_s.hasImage) {
      Fx.i.warn();
      Toaster.i.show('Stamp a word or press a picture into it');
      return;
    }
    if (_s.title.trim().isEmpty) _s.title = DeckMilestones.of(_s.when).label;
    _s.title = _s.title.trim();
    _s.text = _s.text.trim();
    Fx.i.stamp();
    Navigator.pop(context, _s);
  }

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final bottom = MediaQuery.of(context).padding.bottom;
    Widget label(String t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: SectionLabel(t));
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 2, 20, 16 + bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            Text(widget.seal == null ? 'New seal' : 'Edit seal', style: T.d(32, color: mc.ink)),
            const SizedBox(height: 12),
            // The seal, pressed again whenever its look changes.
            Container(
              height: 172,
              foregroundDecoration: texDeco(context, 'tiles', BorderRadius.circular(18)),
              decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(18)),
              child: Center(child: StampedDeckSeal(key: ValueKey(_stamp), seal: _s, size: 116)),
            ),
            const SizedBox(height: 18),
            label('Shape'),
            Seg<String>(
              options: const ['square', 'wide'],
              value: _s.shape,
              height: 38,
              fontSize: 15,
              labelOf: (v) => v == 'square' ? 'Square' : 'Wide',
              onPick: (v) => _restamp(() => _s.shape = v),
            ),
            const SizedBox(height: 18),
            label('Wax'),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final c in DeckSeal.colors)
                Pressable(
                  label: '${sealColorName(c)} wax',
                  haptic: true,
                  onTap: () => _restamp(() => _s.color = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _s.color == c ? mc.ink : Colors.transparent, width: 2.5),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: sealWax(c, mc), shape: BoxShape.circle, boxShadow: mc.e1),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 18),
            FieldLabel(
              'Stamped text',
              trailing: Text('${_text.text.length}/12', style: T.t(13, w: FontWeight.w600, color: mc.muted)),
              child: _LimitedField(controller: _text, hint: 'A word, a number, a monogram', max: 12),
            ),
            const SizedBox(height: 18),
            label('Picture'),
            if (!_s.hasImage)
              SoftButton('Add a PNG or picture',
                  height: 48, icon: McIcon(McIcons.image, size: const Size(18, 18), color: mc.ink), onTap: _pickImage)
            else ...[
              Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: mc.well, borderRadius: BorderRadius.circular(12)),
                  child: cardImage(_s.image!, fit: BoxFit.contain, cacheWidth: 160),
                ),
                const SizedBox(width: 10),
                Expanded(child: SoftButton('Change', height: 46, onTap: _pickImage)),
                const SizedBox(width: 8),
                SoftButton('Remove', height: 46, onTap: () => _restamp(() {
                      _s.image = null;
                      _s.art = 'stamp';
                      _alpha = null;
                    })),
              ]),
              const SizedBox(height: 10),
              Seg<String>(
                options: const ['stamp', 'color'],
                value: _s.art,
                height: 36,
                labelOf: (v) => v == 'stamp' ? 'Pressed into the wax' : 'Its own colours',
                onPick: (v) {
                  if (v == 'stamp' && _alpha == false) {
                    Toaster.i.show('Pressing needs a PNG with a see-through background');
                    return;
                  }
                  _restamp(() => _s.art = v);
                },
              ),
            ],
            const SizedBox(height: 18),
            FieldLabel('Name of the seal', child: _LimitedField(controller: _title, hint: DeckMilestones.of(_s.when).label, max: 24)),
            const SizedBox(height: 18),
            label('Pressed when'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in DeckMilestones.all)
                Opacity(
                  opacity: widget.taken.contains(m.id) ? 0.4 : 1,
                  child: Chip2(
                    m.label,
                    height: 34,
                    selected: _s.when == m.id,
                    onTap: widget.taken.contains(m.id) ? null : () => setState(() => _s.when = m.id),
                  ),
                ),
            ]),
            const SizedBox(height: 6),
            Text(DeckMilestones.of(_s.when).note, style: T.t(13, w: FontWeight.w500, color: mc.muted)),
            const SizedBox(height: 12),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          if (widget.seal != null) ...[
            Expanded(child: SoftButton('Delete', height: 54, textColor: Mc.red, onTap: () => Navigator.pop(context, 'delete'))),
            const SizedBox(width: 10),
          ],
          Expanded(child: InkButton('Save seal', height: 54, size: 23, onTap: _save)),
        ]),
      ]),
    );
  }
}

/// A one-line field that stops at [max] characters.
class _LimitedField extends StatelessWidget {
  const _LimitedField({required this.controller, required this.hint, required this.max});
  final TextEditingController controller;
  final String hint;
  final int max;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    OutlineInputBorder border(Color c) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: 2));
    final style = T.t(18, w: FontWeight.w600, color: mc.ink, height: 1.3);
    return TextField(
      controller: controller,
      maxLines: 1,
      inputFormatters: [LengthLimitingTextInputFormatter(max)],
      style: style,
      cursorColor: mc.ink,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: style.copyWith(color: mc.muted.withValues(alpha: 0.7)),
        filled: true,
        fillColor: mc.field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        enabledBorder: border(mc.line),
        focusedBorder: border(mc.ink),
        border: border(mc.line),
      ),
    );
  }
}
