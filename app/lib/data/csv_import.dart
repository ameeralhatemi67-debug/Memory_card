import 'store.dart';

/// Pasted or file-imported cards: one card per line, front then back, separated by a tab, semicolon or
/// comma (detected), with optional label and example columns. Quoted fields ("a, b") are respected and
/// a header row (front,back,…) is recognised and skipped.
class CsvImport {
  CsvImport._(this.separatorName, this.rows, this.skipped, this.hasHeader);

  final String separatorName;
  final List<CardDraft> rows;
  final int skipped;
  final bool hasHeader;

  static const _cands = [('\t', 'Tab'), (';', 'Semicolon'), (',', 'Comma'), (' | ', 'Pipe'), (' - ', 'Dash')];

  static (String?, String) detect(String text) {
    final lines = text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return (null, 'No separator found');
    for (final (ch, name) in _cands) {
      final hits = lines.where((l) => l.contains(ch)).length;
      if (hits >= (lines.length / 2).ceil()) return (ch, name);
    }
    return (null, 'No separator found');
  }

  static List<String> splitLine(String line, String sep) {
    if (sep.length > 1 || !line.contains('"')) return line.split(sep).map((s) => s.trim()).toList();
    final out = <String>[];
    final buf = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (ch == sep && !quoted) {
        out.add(buf.toString().trim());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    out.add(buf.toString().trim());
    return out;
  }

  static CsvImport parse(String text) {
    final (sep, name) = detect(text);
    final lines = text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    final rows = <CardDraft>[];
    var skipped = 0;
    if (sep == null) return CsvImport._(name, rows, lines.length, false);
    var cols = {'front': 0, 'back': 1, 'label': 2, 'example': 3, 'hook': 4};
    var header = false;
    if (lines.isNotEmpty) {
      final first = splitLine(lines.first, sep).map((s) => s.toLowerCase()).toList();
      const names = {
        'front': ['front', 'question', 'term', 'word', 'prompt'],
        'back': ['back', 'answer', 'definition', 'meaning', 'translation'],
        'label': ['label', 'tag', 'type', 'part of speech'],
        'example': ['example', 'hint', 'context', 'sentence'],
        'hook': ['hook', 'mnemonic', 'note'],
      };
      final found = <String, int>{};
      for (var i = 0; i < first.length; i++) {
        names.forEach((k, v) {
          if (v.contains(first[i]) && !found.containsKey(k)) found[k] = i;
        });
      }
      if (found.containsKey('front') && found.containsKey('back')) {
        header = true;
        cols = {...cols, ...found};
      }
    }
    for (final line in header ? lines.skip(1) : lines) {
      final parts = splitLine(line, sep);
      String at(String k) {
        final i = cols[k]!;
        return i < parts.length ? parts[i] : '';
      }

      final f = at('front'), b = at('back');
      if (f.isEmpty || b.isEmpty) {
        skipped++;
        continue;
      }
      rows.add(CardDraft(front: f, back: b, label: at('label'), example: at('example'), hook: at('hook')));
    }
    return CsvImport._(name, rows, skipped, header);
  }
}
