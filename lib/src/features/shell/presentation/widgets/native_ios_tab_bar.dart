import 'package:cupertino_native_better/cupertino_native_better.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../home/presentation/widgets/home_glass.dart';

/// Which bar an iPhone gets: `native` (the default) or `own`.
///
/// `--dart-define=GUVEN_IOS_NAVBAR=own` builds an iOS app that keeps our own
/// glass bar even on iOS 26 — the way back without touching the code.
const String _kIosNavbar = String.fromEnvironment(
  'GUVEN_IOS_NAVBAR',
  defaultValue: 'native',
);

/// Whether the shell shows Apple's own Liquid Glass tab bar instead of ours.
///
/// Only an iPhone on iOS 26 or later has it: the bar is a real `UITabBar`,
/// and its glass is the system's, which exists from iOS 26 on. Android and
/// older iPhones keep `GuvenGlassBottomBar`, which draws the same design on
/// every phone with our own shader.
bool useNativeIosTabBar() {
  if (_kIosNavbar == 'own') return false;
  if (defaultTargetPlatform != TargetPlatform.iOS) return false;
  return PlatformVersion.isIOS26OrLater;
}

/// Apple's own iOS 26 tab bar, fed from the shell like our own bar is.
///
/// It is a native `UITabBar` shown through a platform view, so iOS draws the
/// glass, the label font and the selection lens itself — none of our shader,
/// springs or measured markers are involved. What it takes from us:
///
/// - the same five cells, labels and SVG glyphs (iOS tints them itself);
/// - the selected cell, which Flutter owns: a tap is reported, the shell
///   decides, and the bar follows. Every tap is reported, the selected
///   cell's included, so `Daha çox` hears the second tap that shuts its fan;
/// - `Daha çox`'s glyph, swapped to its open form while the fan is out.
///
/// What it cannot do, because a `UITabBar` has no such thing: lift a cell out
/// with a long press. Pages are still rearranged from the fan, and a fan
/// button dropped on the bar lands in it.
class NativeIosTabBar extends StatelessWidget {
  const NativeIosTabBar({
    super.key,
    required this.labels,
    required this.icons,
    required this.selectedIndex,
    required this.onSelected,
    required this.menuIndex,
    required this.menuOpenIcon,
    required this.menuOpen,
  }) : assert(labels.length == icons.length);

  final List<String> labels;

  /// One SVG asset path per cell.
  final List<String> icons;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// The `Daha çox` cell, whose glyph changes while [menuOpen].
  final int menuIndex;
  final String menuOpenIcon;
  final bool menuOpen;

  /// Apple's own tab glyph size — the bar is sized around it.
  static const double _iconSize = 25;

  @override
  Widget build(BuildContext context) {
    return CNTabBar(
      items: <CNTabBarItem>[
        for (int cell = 0; cell < labels.length; cell++)
          CNTabBarItem(
            label: labels[cell],
            imageAsset: CNImageAsset(
              cell == menuIndex && menuOpen ? menuOpenIcon : icons[cell],
              size: _iconSize,
            ),
          ),
      ],
      currentIndex: selectedIndex,
      onTap: onSelected,
      // The glyphs and names in the app's own ink rather than iOS's blue;
      // the selection is shown by Apple's lens under them, as ours was by
      // the grey marker.
      tint: kGlassInk,
    );
  }
}
