import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/card_layout.dart';
import '../../data/csv_import.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../data/store_scope.dart';
import '../../engine/seals.dart';
import '../../ui/fx.dart';
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../../ui/overlays.dart';
import '../../ui/textures.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../decks/deck_maker.dart';
import '../layout/layout_editor.dart';
import '../layout/layout_face.dart';
import '../layout/pick_picture.dart';
import '../study/celebrate.dart';

/// Opens the editor sheet (canvas Editor.dc.html): write a card, or paste / pick a CSV.
Future<void> showEditor(
  BuildContext context, {
  String? deckId,
  String? folderId,
  String? editCardId,
  bool newDeck = false,
  bool startOnImport = false,
}) async {
  final store = context.storeRead;
  var target = deckId;
  if (newDeck) {
    target = await createDeckFlow(context, folderId: folderId ?? store.currentFolder?.id);
    if (target == null || !context.mounted) return;
  }
  if (!context.mounted) return;
  await showMcSheet(
    context,
    builder: (ctx) => EditorSheet(deckId: target, folderId: folderId, editCardId: editCardId, startOnImport: startOnImport),
  );
  final seals = store.takePendingSeals();
  if (seals.isNotEmpty && context.mounted) announceSeals(context, seals);
}

/// Languages offered for "Hear it" on your own decks.
const deckLanguages = <(String?, String)>[
  (null, 'None'),
  ('en-GB', 'English'),
  ('de-DE', 'German'),
  ('es-ES', 'Spanish'),
  ('fr-FR', 'French'),
  ('it-IT', 'Italian'),
  ('pt-BR', 'Portuguese'),
  ('nl-NL', 'Dutch'),
  ('ru-RU', 'Russian'),
  ('tr-TR', 'Turkish'),
  ('ar-SA', 'Arabic'),
  ('ja-JP', 'Japanese'),
  ('zh-CN', 'Chinese'),
  ('ko-KR', 'Korean'),
  ('hi-IN', 'Hindi'),
  ('el-GR', 'Greek'),
  ('sw-KE', 'Swahili'),
];

/// Makes a new deck in the deck maker (its name, language, look and seals). Returns the new deck's id.
Future<String?> createDeckFlow(BuildContext context, {String? folderId}) => openDeckMaker(context, folderId: folderId);

class EditorSheet extends StatefulWidget {
  const EditorSheet({super.key, this.deckId, this.folderId, this.editCardId, this.startOnImport = false});
  final String? deckId;
  final String? folderId;
  final String? editCardId;
  final bool startOnImport;

  @override
  State<EditorSheet> createState() => _EditorSheetState();
}

class _EditorSheetState extends State<EditorSheet> {
  late final AppStore store = context.storeRead;
  late bool _import = widget.startOnImport;
  String? _deckId;
  final _front = TextEditingController();
  final _back = TextEditingController();
  final _example = TextEditingController();
  final _hook = TextEditingController();
  final _csv = TextEditingController();
  final _frontFocus = FocusNode();
  bool _reverse = false;
  bool _showHook = false;
  String? _image;

  /// How each side is laid out; null = the classic text card.
  SideLayout? _fl, _bl;
  int _saved = 0;
  int _shakeFront = 0, _shakeBack = 0;

  CardItem? get _editing => widget.editCardId == null ? null : store.data.cards[widget.editCardId];

  @override
  void initState() {
    super.initState();
    final e = _editing;
    if (e != null) {
      _deckId = e.deckId;
      _front.text = e.front;
      _back.text = e.back;
      _example.text = e.example;
      _hook.text = e.hook;
      _showHook = e.hook.isNotEmpty;
      _image = e.image;
      _fl = e.frontLayout?.copy();
      _bl = e.backLayout?.copy();
      _reverse = e.siblingId != null;
    } else {
      _deckId = widget.deckId ?? _guessDeck();
      final d = _deckId == null ? null : store.data.decks[_deckId];
      _reverse = d?.category == 'lang';
    }
    _csv.addListener(() => setState(() {}));
    // The little previews follow what you type.
    for (final c in [_front, _back, _example, _hook]) {
      c.addListener(_typed);
    }
  }

  void _typed() {
    if (mounted) setState(() {});
  }

  String? _guessDeck() {
    final f = store.data.folderById(widget.folderId) ?? store.currentFolder;
    if (f != null) {
      final own = store.decksIn(f).where((d) => d.catalogId == null).toList();
      if (own.isNotEmpty) return own.first.id;
      if (f.deckIds.isNotEmpty) return f.deckIds.first;
    }
    final last = store.data.lastDeckId;
    if (last != null && store.data.decks.containsKey(last)) return last;
    return store.data.decks.isEmpty ? null : store.data.decks.keys.first;
  }

  @override
  void dispose() {
    for (final c in [_front, _back, _example, _hook]) {
      c.removeListener(_typed);
    }
    _front.dispose();
    _back.dispose();
    _example.dispose();
    _hook.dispose();
    _csv.dispose();
    _frontFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDeck() async {
    final mc = Mc.of(context);
    final picked = await showMcSheet<String>(
      context,
      expand: false,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Which deck?', style: T.d(30, color: mc.ink)),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final f in store.data.folders)
                    if (f.deckIds.isNotEmpty) ...[
                      Padding(padding: const EdgeInsets.fromLTRB(2, 10, 0, 6), child: SectionLabel(f.name)),
                      for (final d in store.decksIn(f))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Pressable(
                            onTap: () => Navigator.pop(ctx, d.id),
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: d.id == _deckId ? mc.ink : mc.soft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(children: [
                                Expanded(
                                  child: Text(d.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: T.d(20, color: d.id == _deckId ? mc.canvas : mc.ink)),
                                ),
                                Text('${d.cardIds.length}',
                                    style: T.t(14, w: FontWeight.w600, color: d.id == _deckId ? mc.mutedOnInk : mc.muted)),
                              ]),
                            ),
                          ),
                        ),
                    ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            SoftButton('+ New deck', onTap: () => Navigator.pop(ctx, '__new')),
          ],
        ),
      ),
    );
    if (!mounted || picked == null) return;
    if (picked == '__new') {
      final id = await createDeckFlow(context, folderId: widget.folderId ?? store.currentFolder?.id);
      if (id != null && mounted) setState(() => _deckId = id);
    } else {
      setState(() => _deckId = picked);
    }
  }

  /// A picture is on this side (from its layout, or the older single picture on the front).
  bool _hasPicture(bool back) => back ? (_bl?.hasImage ?? false) : (_fl?.hasImage ?? (_image != null && _image!.isNotEmpty));

  Future<void> _openLayout(bool back) async {
    FocusScope.of(context).unfocus();
    final deck = _deckId == null ? null : store.data.decks[_deckId];
    final label = deck == null ? 'card' : (deck.category == 'custom' ? 'card' : deck.level);
    final r = await showLayoutEditor(
      context,
      back: back,
      initial: back ? _bl : _fl,
      main: back ? _back : _front,
      example: _example,
      hook: _hook,
      label: label.isEmpty ? 'card' : label,
      code: !back && deck?.kind == 'code',
      legacyPicture: back || _fl != null ? null : _image,
    );
    if (r == null || !mounted) return;
    setState(() {
      if (back) {
        _bl = r.layout;
      } else {
        _fl = r.layout;
        _image = null; // the layout now owns the front's picture
      }
    });
  }

  /// The quick path: pick a picture and it goes under the text; fine-tune it in the layout editor.
  Future<void> _quickPicture(bool back) async {
    FocusScope.of(context).unfocus();
    final p = await pickPicture(context);
    if (p == null || !mounted) return;
    final layout = SideLayout.forPicture(
      Tpl.below,
      back: back,
      src: p.src,
      aspect: p.aspect,
      alpha: p.alpha,
      contain: p.alpha,
      blur: back,
    );
    setState(() {
      if (back) {
        _bl = layout;
      } else {
        _fl = layout;
        _image = null;
      }
    });
  }

  bool _validate() {
    var ok = true;
    // A side can be only a picture.
    if (_front.text.trim().isEmpty && !_hasPicture(false)) {
      setState(() => _shakeFront++);
      ok = false;
    }
    if (_back.text.trim().isEmpty && !_hasPicture(true)) {
      setState(() => _shakeBack++);
      ok = false;
    }
    if (!ok) Fx.i.warn();
    return ok;
  }

  CardDraft get _draft => CardDraft(
        front: _front.text,
        back: _back.text,
        example: _example.text,
        hook: _hook.text,
        image: _fl == null ? _image : null,
        frontLayout: _fl,
        backLayout: _bl,
      );

  Future<void> _saveNext() async {
    if (_deckId == null) {
      await _pickDeck();
      if (_deckId == null) return;
    }
    if (!_validate()) return;
    store.addCard(_deckId!, _draft, reverse: _reverse);
    Fx.i.pop();
    setState(() {
      _saved++;
      _front.clear();
      _back.clear();
      _example.clear();
      _hook.clear();
      _image = null;
      _fl = null;
      _bl = null;
    });
    _frontFocus.requestFocus();
  }

  void _done() {
    if (_front.text.trim().isNotEmpty || _back.text.trim().isNotEmpty || _hasPicture(false) || _hasPicture(true)) {
      if (_deckId == null || !_validate()) return;
      store.addCard(_deckId!, _draft, reverse: _reverse);
      _saved++;
    }
    final d = _deckId == null ? null : store.data.decks[_deckId];
    Navigator.pop(context);
    if (_saved > 0 && d != null) Toaster.i.show('$_saved ${_saved == 1 ? 'card' : 'cards'} added to ${d.name}');
  }

  void _saveEdit() {
    final e = _editing!;
    if (!_validate()) return;
    store.updateCard(e.id, _draft);
    if (!e.isReverse && _reverse != (e.siblingId != null)) store.setReverse(e.id, _reverse);
    Navigator.pop(context);
    Toaster.i.show('Card saved');
  }

  Future<void> _delete() async {
    final e = _editing!;
    final ok = await confirm(context, title: 'Delete this card?', message: 'Its history goes with it. You can undo right after.');
    if (!ok || !mounted) return;
    final undo = store.deleteCard(e.id);
    Navigator.pop(context);
    Toaster.i.show('Card deleted', undo: undo);
  }

  Future<void> _pickCsv() async {
    try {
      final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['csv', 'txt', 'tsv']);
      if (f == null) return;
      final text = await f.xFile.readAsString();
      _csv.text = text;
    } catch (_) {
      Toaster.i.show('Could not read that file');
    }
  }

  Future<void> _runImport(CsvImport parsed) async {
    if (parsed.rows.isEmpty) return;
    var deckId = _deckId;
    deckId ??= await createDeckFlow(context, folderId: widget.folderId ?? store.currentFolder?.id);
    if (deckId == null || !mounted) return;
    final d = store.data.decks[deckId]!;
    final n = store.importRows(deckId, parsed.rows, reverse: _reverse);
    Fx.i.pop();
    Navigator.pop(context);
    Toaster.i.show('Imported $n ${n == 1 ? 'card' : 'cards'} into ${d.name}');
    final seals = Seals.checkAuthoring(store.data, store.ownCardCount);
    if (seals.isNotEmpty) announceSeals(context, seals);
  }

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final editing = _editing;
    final deck = _deckId == null ? null : store.data.decks[_deckId];
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 2, 20, 16 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (editing == null)
            Seg<bool>(
              options: const [false, true],
              value: _import,
              labelOf: (v) => v ? 'Import CSV' : 'Card',
              onPick: (v) => setState(() => _import = v),
              height: 40,
              fontSize: 16,
              background: mc.soft,
            ),
          const SizedBox(height: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: McCurves.out,
              transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a), child: c),
              ),
              child: _import && editing == null ? _importPane(mc, deck) : _cardPane(mc, deck, editing),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deckPill(Mc mc, Deck? deck) => Pressable(
        onTap: _pickDeck,
        child: Container(
          height: 34,
          constraints: const BoxConstraints(maxWidth: 190),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundDecoration: texDeco(context, 'tiles', BorderRadius.circular(17)),
          decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(17)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: Text(deck?.name ?? '+ New deck',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: T.t(14, w: FontWeight.w700, color: mc.ink)),
            ),
            const SizedBox(width: 4),
            Transform.rotate(angle: math.pi / 2, child: McIcon(McIcons.chevron, size: const Size(13, 13), color: mc.ink)),
          ]),
        ),
      );

  Widget _cardPane(Mc mc, Deck? deck, CardItem? editing) {
    // The buttons stay put under the form: with pictures the form can be taller than the sheet.
    final buttons = editing == null
        ? Row(children: [
            Expanded(child: SoftButton('Done', height: 54, onTap: _done)),
            const SizedBox(width: 10),
            Expanded(child: InkButton(_saved > 0 ? 'Saved $_saved · next' : 'Save & next', height: 54, size: 23, onTap: _saveNext)),
          ])
        : Row(children: [
            Expanded(child: SoftButton('Delete', height: 54, textColor: Mc.red, onTap: _delete)),
            const SizedBox(width: 10),
            Expanded(child: InkButton('Save', height: 54, size: 23, onTap: _saveEdit)),
          ]);
    return Column(
      key: const ValueKey('card'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: ListView(
      padding: EdgeInsets.zero,
      children: [
        Row(children: [
          Expanded(child: Text(editing == null ? 'New card' : 'Edit card', style: T.d(32, color: mc.ink))),
          if (editing == null) _deckPill(mc, deck),
        ]),
        const SizedBox(height: 12),
        _Shake(
          trigger: _shakeFront,
          child: FieldLabel('Front',
              child: McField(
                controller: _front,
                focusNode: _frontFocus,
                hint: deck?.category == 'lang' ? 'der Apfel' : 'A question or a word',
                display: deck?.kind != 'code',
                mono: deck?.kind == 'code',
                autofocus: editing == null,
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.next,
              )),
        ),
        const SizedBox(height: 12),
        _Shake(
          trigger: _shakeBack,
          child: FieldLabel('Back',
              child: McField(
                controller: _back,
                hint: deck?.category == 'lang' ? 'the apple' : 'The answer',
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.next,
              )),
        ),
        const SizedBox(height: 12),
        FieldLabel('Example or hint (optional)',
            child: McField(controller: _example, hint: 'Shown before the answer, never the answer itself', maxLines: 3, minLines: 2, size: 17)),
        const SizedBox(height: 10),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: McCurves.out,
          alignment: Alignment.topCenter,
          child: _showHook
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FieldLabel('Memory hook (optional)',
                      child: McField(controller: _hook, hint: 'A picture or a link that makes it stick', maxLines: 2, minLines: 1, size: 17)),
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Pressable(
                      onTap: () => setState(() => _showHook = true),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        McIcon(McIcons.lightbulb, size: const Size(18, 18), color: mc.muted),
                        const SizedBox(width: 6),
                        Text('Add a memory hook', style: T.t(15, w: FontWeight.w700, color: mc.muted)),
                      ]),
                    ),
                  ),
                ),
        ),
        _design(mc, deck),
        if (editing == null || !editing.isReverse) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Also study it in reverse', style: T.t(16, w: FontWeight.w700, color: mc.ink)),
                Text('Creates a reverse card, kept apart in the stack', style: T.t(14, w: FontWeight.w500, color: mc.muted)),
              ]),
            ),
            McSwitch(value: _reverse, onChanged: (v) => setState(() => _reverse = v), label: 'Also study back to front'),
          ]),
        ],
        const SizedBox(height: 12),
      ],
    )),
        const SizedBox(height: 10),
        buttons,
      ],
    );
  }

  /// Both sides of the card as small previews: tap one to arrange its pictures and text.
  Widget _design(Mc mc, Deck? deck) {
    Widget side(bool back) {
      final layout = back ? _bl : _fl;
      final legacy = !back && _fl == null && _image != null && _image!.isNotEmpty ? _image : null;
      final shown = layout ??
          (legacy != null ? SideLayout.forPicture(Tpl.below, back: false, src: legacy) : SideLayout.template(Tpl.text, back: back));
      final texts = LayoutTexts(
        main: back ? _back.text : _front.text,
        example: _example.text,
        hook: _hook.text,
        code: !back && deck?.kind == 'code',
      );
      final pictures = shown.images.length;
      final note = layout == null && legacy == null
          ? 'Text only'
          : '${pictures == 0 ? 'Text' : '$pictures ${pictures == 1 ? 'picture' : 'pictures'}'} · ${shown.mode == LayoutMode.canvas ? 'free canvas' : 'guided'}';
      return Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(back ? 'Back' : 'Front', style: T.t(14, w: FontWeight.w700, color: mc.muted)),
          const SizedBox(height: 5),
          Center(
            child: Pressable(
              onTap: () => _openLayout(back),
              label: 'Arrange the ${back ? 'back' : 'front'}',
              child: Container(
                width: 112,
                height: 112 * 384 / 276,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: back ? Mc.peach : mc.ink,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: mc.e1,
                ),
                child: Stack(fit: StackFit.expand, children: [
                  LayoutFace(layout: shown, texts: texts, back: back),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xCC222222), borderRadius: BorderRadius.circular(9)),
                      child: Text('Arrange', style: T.t(11.5, w: FontWeight.w700, color: Mc.paper)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(note, textAlign: TextAlign.center, style: T.t(13, w: FontWeight.w600, color: mc.muted)),
          const SizedBox(height: 6),
          Center(
            child: Chip2(
              _hasPicture(back) ? 'Change picture' : '+ Picture',
              height: 32,
              onTap: () => _hasPicture(back) ? _openLayout(back) : _quickPicture(back),
            ),
          ),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Pictures & layout', style: T.t(16, w: FontWeight.w700, color: mc.ink)),
        Text('Put a picture on either side, or on both. PNG cut-outs keep their see-through background.',
            style: T.t(14, w: FontWeight.w500, color: mc.muted, height: 1.3)),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [side(false), const SizedBox(width: 12), side(true)]),
      ]),
    );
  }

  Widget _importPane(Mc mc, Deck? deck) {
    final parsed = CsvImport.parse(_csv.text);
    return ListView(
      key: const ValueKey('import'),
      padding: EdgeInsets.zero,
      children: [
        Row(children: [
          Expanded(child: Text('Import cards', style: T.d(32, color: mc.ink))),
          _deckPill(mc, deck),
        ]),
        const SizedBox(height: 8),
        Text('Paste one card per line: front, then back, separated by a tab, comma or semicolon. '
            'A third column becomes the label, a fourth the example.',
            style: T.t(15, w: FontWeight.w500, color: mc.muted, height: 1.35)),
        const SizedBox(height: 12),
        FieldLabel('Paste here',
            child: McField(controller: _csv, hint: 'der Apfel; the apple\ndie Birne; the pear', mono: true, maxLines: 6, minLines: 5)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Chip2('Separator: ${parsed.separatorName}'),
          Chip2('${parsed.rows.length} ${parsed.rows.length == 1 ? 'card' : 'cards'}'),
          if (parsed.hasHeader) const Chip2('Header row found'),
          if (parsed.skipped > 0)
            Chip2('${parsed.skipped} ${parsed.skipped == 1 ? 'line' : 'lines'} skipped', color: Mc.peach, textColor: Mc.graphite),
        ]),
        if (parsed.rows.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(border: Border.all(color: mc.line, width: 2), borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              Container(
                color: mc.soft,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  Expanded(child: Text('FRONT', style: T.caps(13, color: mc.muted, spacing: 1))),
                  Expanded(child: Text('BACK', style: T.caps(13, color: mc.muted, spacing: 1))),
                ]),
              ),
              for (final r in parsed.rows.take(4))
                Container(
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: mc.line))),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    Expanded(child: Text(r.front, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.t(16, w: FontWeight.w600, color: mc.ink))),
                    Expanded(child: Text(r.back, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.t(16, w: FontWeight.w600, color: mc.ink))),
                  ]),
                ),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Text('Also study it in reverse', style: T.t(16, w: FontWeight.w700, color: mc.ink)),
          ),
          McSwitch(value: _reverse, onChanged: (v) => setState(() => _reverse = v), label: 'Also study back to front'),
        ]),
        const SizedBox(height: 14),
        Pressable(
          onTap: _pickCsv,
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: mc.line, width: 2), borderRadius: BorderRadius.circular(16)),
            child: Text('Choose a .csv or .txt file…', style: T.t(16, w: FontWeight.w700, color: mc.ink)),
          ),
        ),
        const SizedBox(height: 10),
        InkButton(
          parsed.rows.isEmpty ? 'Paste some cards first' : 'Import ${parsed.rows.length} cards',
          enabled: parsed.rows.isNotEmpty,
          onTap: () => _runImport(parsed),
        ),
      ],
    );
  }
}

/// A dashed rounded border (the "Add image" well).
class DashedBox extends StatelessWidget {
  const DashedBox({super.key, required this.child, required this.color});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _Dash(color), child: child);
}

class _Dash extends CustomPainter {
  _Dash(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)).deflate(1);
    final path = Path()..addRRect(r);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 7), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_Dash old) => old.color != color;
}

/// Shakes its child sideways when [trigger] changes (an empty required field).
class _Shake extends StatefulWidget {
  const _Shake({required this.trigger, required this.child});
  final int trigger;
  final Widget child;

  @override
  State<_Shake> createState() => _ShakeState();
}

class _ShakeState extends State<_Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));

  @override
  void didUpdateWidget(_Shake old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = _c.value;
          final dx = (1 - t) * 10 * math.sin(t * 6 * math.pi);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: widget.child,
      );
}
