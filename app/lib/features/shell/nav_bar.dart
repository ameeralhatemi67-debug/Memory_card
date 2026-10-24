import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/fx.dart';
import '../../ui/icons.dart';
import '../../ui/textures.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'shell.dart';

/// Home · Lab · the + diamond · Shop · Account (canvas Main.dc.html nav, 112px tall).
class NavBar extends StatelessWidget {
  const NavBar({
    super.key,
    required this.current,
    required this.onHome,
    required this.onLab,
    required this.onCreate,
    required this.onShop,
    required this.onAccount,
    this.diamondKey,
  });

  static const height = 104.0;

  final ShellTab current;
  final VoidCallback onHome;
  final VoidCallback onLab;
  final VoidCallback onCreate;
  final VoidCallback onShop;
  final VoidCallback onAccount;

  /// Marks the + so the create menu can rise from it.
  final Key? diamondKey;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    Widget slot(String icon, Size size, String label, ShellTab tab, VoidCallback onTap) => Expanded(
          child: Center(
            child: _NavIcon(icon: icon, size: size, label: label, selected: current == tab, onTap: onTap),
          ),
        );
    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(bottom: bottom + 8, left: 8, right: 8),
      child: Row(
        children: [
          slot(McIcons.home, const Size(40, 40), 'Home', ShellTab.decks, onHome),
          slot(McIcons.lab, const Size(40, 40), 'Memory Lab', ShellTab.lab, onLab),
          _PlusDiamond(key: diamondKey, onTap: onCreate),
          slot(McIcons.shop, const Size(44, 38), 'Shop', ShellTab.shop, onShop),
          slot(McIcons.account, const Size(38, 38), 'Account', ShellTab.account, onAccount),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, required this.size, required this.label, required this.selected, required this.onTap});
  final String icon;
  final Size size;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Pressable(
      label: label,
      scale: 0.88,
      onTap: () {
        Fx.i.tap();
        onTap();
      },
      child: SizedBox(
        width: 60,
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            McIcon(icon, size: size, color: mc.ink),
            const SizedBox(height: 4),
            AnimatedScale(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              scale: selected ? 1 : 0,
              child: Container(width: 6, height: 6, decoration: BoxDecoration(color: mc.ink, shape: BoxShape.circle)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The rotated-square "+" (58×58, radius 15, floating shadow).
class _PlusDiamond extends StatelessWidget {
  const _PlusDiamond({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    return Pressable(
      label: 'Create',
      scale: 0.9,
      haptic: true,
      onTap: onTap,
      child: SizedBox(
        width: 84,
        height: 84,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: 58,
                height: 58,
                foregroundDecoration: texDeco(context, 'buttons', BorderRadius.circular(15)),
                decoration: BoxDecoration(color: mc.ink, borderRadius: BorderRadius.circular(15), boxShadow: mc.e2),
              ),
            ),
            McIcon(McIcons.plus, size: const Size(30, 30), color: mc.canvas),
          ],
        ),
      ),
    );
  }
}
