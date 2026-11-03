import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/engine/make24.dart';

/// The way matching the app does on the card agrees with tools/make24.py for every shipped Make 24 card.
void main() {
  final decks = (jsonDecode(File('assets/content/catalog.json').readAsStringSync()) as Map)['decks'] as List;
  final cards = [
    for (final d in decks)
      if ((d as Map)['kind'] == 'make24') ...(d['cards'] as List).cast<Map>(),
  ];

  test('12 decks of 63', () {
    final make24 = decks.where((d) => (d as Map)['kind'] == 'make24').toList();
    expect(make24.length, 12);
    expect(make24.every((d) => ((d as Map)['cards'] as List).length == 63), isTrue);
    expect(cards.length, 756);
  });

  test('every way reads back as itself, makes 24 in three steps, with its four numbers', () {
    for (final c in cards) {
      final nums = (c['front'] as String).split(' ').map(int.parse).toList()..sort();
      for (final w in (c['ways'] as List).cast<String>()) {
        final e = Expr.parse(w);
        expect(wayOf(e), w, reason: '${c['front']}: $w');
        expect(e.value, Frac.target, reason: w);
        expect([...e.numbers]..sort(), nums, reason: w);
        expect(e.steps.length, 3, reason: w);
        expect(e.steps.last.endsWith('= 24'), isTrue, reason: w);
      }
    }
  });

  test('order and grouping do not make a new way', () {
    expect(wayOf(Expr.parse('((8-6)*3)*4')), wayOf(Expr.parse('((8-6)*4)*3')));
    expect(wayOf(Expr.parse('4*(5+7-6)')), '(7 + 5 − 6) × 4');
    expect(wayOf(Expr.parse('11*1+7+6')), wayOf(Expr.parse('6*1+11+7')));
    expect(Expr.parse('(8 − 6) × 4 × 3').steps, ['8 − 6 = 2', '2 × 4 = 8', '8 × 3 = 24']);
    expect(Expr.parse('8 ÷ (3 − 8 ÷ 3)').steps, ['8 ÷ 3 = 8/3', '3 − 8/3 = 1/3', '8 ÷ 1/3 = 24']);
  });
}
