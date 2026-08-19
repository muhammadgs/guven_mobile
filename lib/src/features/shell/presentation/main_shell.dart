import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/layout.dart';
import '../../../shared/widgets/app_background.dart';
import '../../home/presentation/home_screen.dart';
import 'widgets/coming_soon_tab.dart';
import 'widgets/guven_glass_bottom_bar.dart';

/// The signed-in app: one background, five tabs, and the glass bar over them.
///
/// The page sits under the app-owned glass bar so both the bar and its moving
/// selection lens can refract the actual tab artwork behind them.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// Cell order is the design's, not reading order — `Əsas səhifə` sits
  /// fourth, not first.
  static const int homeIndex = 3;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = MainShell.homeIndex;

  static const List<String> _titles = <String>[
    'Şirkətlər',
    'Əməkdaşlar',
    'Daha çox',
    'Əsas səhifə',
    'Tapşırıqlar',
  ];

  /// The design's own glyphs, in cell order beside [_titles].
  static const List<String> _icons = <String>[
    'assets/images/icons/nav_icons/company.svg',
    'assets/images/icons/nav_icons/workers.svg',
    'assets/images/icons/nav_icons/menu.svg',
    'assets/images/icons/nav_icons/home.svg',
    'assets/images/icons/nav_icons/tasks.svg',
  ];

  /// Distance from the screen edge to the bar capsule.
  static const double _barSideInset = 18;

  /// Gap between the capsule and the bottom safe area.
  static const double _barBottomGap = 10;

  /// Smallest distance the capsule keeps from the physical screen edge when
  /// there is no system inset to sit above — which is every Android phone now
  /// that `MainActivity` hides the navigation bar.
  static const double _barMinBottomMargin = 16;

  static const double _barHeight = 64;

  @override
  Widget build(BuildContext context) {
    final double barHeight = scaled(context, _barHeight);
    final double barGap = scaled(context, _barBottomGap);
    // `MainActivity` hides Android's navigation bar, so on those phones the
    // bottom inset is now zero and the capsule would sit ten points off the
    // physical edge. A floor keeps it floating rather than resting on the rim,
    // and never shortens the gesture-navigation inset it used to follow.
    final double barFloor = math.max(
      MediaQuery.paddingOf(context).bottom,
      scaled(context, _barMinBottomMargin),
    );
    // What the page has to keep clear at the bottom. The bar floats over the
    // content, so nothing in the layout knows about it unless it is told.
    final double reserve =
        barFloor + barGap + barHeight + scaled(context, 12);

    return AppBackground(
      // The tabs are not Scaffolds — the background and the nav bar are shared
      // and live out here — so this is the only Material in the signed-in
      // tree. Without one, `Text` falls back to the framework's yellow-striped
      // debug style and `RefreshIndicator`/`TextButton` have no ink surface.
      // `transparency` paints nothing and, at the default `Clip.none`, adds no
      // layer for the lenses below to lose their backdrop to.
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _page(reserve),
            Align(
              alignment: Alignment.bottomCenter,
              // The bar sizes to its content rather than filling the stack, so
              // it is anchored here and the floor is added by hand — it knows
              // nothing about the home indicator underneath it.
              child: Padding(
                padding: EdgeInsets.only(bottom: barFloor),
                child: _navBar(barHeight, barGap),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navBar(double barHeight, double barGap) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: scaled(context, _barSideInset),
        vertical: barGap,
      ),
      child: SizedBox(
        height: barHeight,
        child: GuvenGlassBottomBar(
          labels: _titles,
          icons: _icons,
          selectedIndex: _index,
          onSelected: _select,
          height: barHeight,
          iconSize: scaled(context, 22),
          textStyle: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
            fontSize: scaled(context, 10),
            height: 1.1,
          ),
        ),
      ),
    );
  }

  /// Keeps every tab that has been visited alive, so returning to the home
  /// screen does not re-run its four requests.
  Widget _page(double reserve) {
    return IndexedStack(
      index: _index,
      children: <Widget>[
        for (int i = 0; i < _titles.length; i++)
          if (i == MainShell.homeIndex)
            HomeScreen(bottomReserve: reserve)
          else
            ComingSoonTab(title: _titles[i], bottomReserve: reserve),
      ],
    );
  }

  /// Every cell selects, including `Daha çox` — its *section* is what is not
  /// built yet, and an unbuilt section is a `ComingSoonTab` like the other
  /// three.
  void _select(int next) {
    if (next == _index) return;
    setState(() => _index = next);
  }
}
