import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/data/models.dart';
import 'package:memory_card/ui/textures.dart';

void main() {
  test('texture settings survive a save and load', () {
    final s = Settings();
    s.texture.layers['wallLight']!
      ..style = 'brick'
      ..strength = 0.8;
    s.texture
      ..vignette = true
      ..vignetteStrength = 0.3
      ..windowLight = false;
    final back = Settings.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map);
    expect(back.texture.layer('wallLight').style, 'brick');
    expect(back.texture.layer('wallLight').strength, 0.8);
    expect(back.texture.vignette, isTrue);
    expect(back.texture.vignetteStrength, 0.3);
    expect(back.texture.windowLight, isFalse);
  });

  test('saves from before textures get the defaults: a plaster wall in light mode', () {
    final s = Settings.fromJson({'goal': 30});
    expect(s.goal, 30);
    expect(s.texture.enabled, isTrue);
    expect(s.texture.layer('wallLight').style, 'plaster');
    expect(s.texture.layer('grain').on, isFalse);
  });

  test('every offered texture exists, and every element has choices and a ceiling', () {
    for (final e in TextureSettings.defaults.keys) {
      expect(Textures.choices[e], isNotNull, reason: e);
      expect(Textures.maxOpacity[e], isNotNull, reason: e);
      expect(Textures.choices[e], contains(TextureSettings.defaults[e]!.style), reason: e);
      for (final id in Textures.choices[e]!) {
        if (id == 'none' || id == 'wall') continue;
        expect(Textures.def(id), isNotNull, reason: '$e → $id');
      }
    }
  });

  test('turning textures off leaves every element plain', () {
    final t = TextureSettings()..enabled = false;
    Textures.i.update(t);
    for (final e in TextureSettings.defaults.keys) {
      expect(Textures.i.resolveLayer(e, dark: false), isNull, reason: e);
    }
    Textures.i.update(TextureSettings());
    expect(Textures.i.resolveLayer('wallLight', dark: false)?.def.id, 'plaster');
    expect(Textures.i.resolveLayer('sheets', dark: true)?.def.id, 'felt');
  });
}
