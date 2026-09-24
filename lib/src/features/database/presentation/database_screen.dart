import 'package:flutter/material.dart';

import '../../../shared/layout.dart';
import '../../auth/application/session_controller.dart';
import '../../tasks/presentation/widgets/task_tools.dart';
import '../application/database_controller.dart';
import '../domain/database_metric.dart';
import '../domain/database_section.dart';
import 'database_format.dart';
import 'widgets/database_glass.dart';
import 'widgets/database_menu.dart';
import 'widgets/database_overview_row.dart';

/// Baza — the company's 1C data, one page at a time.
///
/// `Baza` over the name of the page on screen, the menu button under them,
/// and the page below. `Əsas panel` is the first page and the only one built
/// so far; the rest are in the menu and say so when chosen.
///
/// Nothing scrolls except the page: the titles and the button are the fixed
/// frame, as they are on the task list.
class DatabaseScreen extends StatefulWidget {
  const DatabaseScreen({
    super.key,
    required this.bottomReserve,
    required this.active,
    this.controller,
  });

  /// Vertical space the floating nav bar occupies, which this screen must keep
  /// clear at the bottom of its list.
  final double bottomReserve;

  /// Whether this is the tab on screen.
  ///
  /// The shell builds every page at sign-in, and without this `Baza` would ask
  /// the 1C bridge for four answers on launch, for a tab nobody has opened.
  final bool active;

  /// Injected by the widget tests, which have no bridge to ask.
  @visibleForTesting
  final DatabaseController? controller;

  @override
  State<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends State<DatabaseScreen> {
  DatabaseController? _controller;

  /// True while the menu is up. The button steps aside for it, because the
  /// menu *is* the button's glass.
  bool _menuOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??=
        widget.controller ?? DatabaseController(SessionScope.read(context));
    if (widget.active) _loadOnce();
  }

  @override
  void didUpdateWidget(covariant DatabaseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _loadOnce();
  }

  /// The first visit loads; later ones keep what is already there, and a pull
  /// is what goes back to the network.
  void _loadOnce() {
    final DatabaseController database = _controller!;
    if (database.hasLoaded || database.isLoading) return;
    database.load();
  }

  @override
  void dispose() {
    // Only the one this screen made. An injected controller belongs to
    // whoever injected it.
    if (widget.controller == null) _controller?.dispose();
    super.dispose();
  }

  /// Opens `Detallar`, growing out of the button that was pressed.
  Future<void> _openMenu(Rect button, double radius) async {
    final DatabaseController database = _controller!;
    setState(() => _menuOpen = true);
    await openDatabaseMenu(
      context,
      button: button,
      radius: radius,
      current: database.section,
      onSelect: database.select,
    );
    if (mounted) setState(() => _menuOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final DatabaseController database = _controller!;
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    // The design's own numbers, on its own frame (see [kDatabaseFrame]).
    final double s = databaseScale(context);
    // The task list's button, at the task list's size: the user asked for it
    // to be exactly those.
    final double button = scaled(context, 42);

    return ListenableBuilder(
      listenable: database,
      builder: (BuildContext context, _) {
        final DatabaseSection section = database.section;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            33.5 * s,
            safe.top + 14 * s,
            33.5 * s,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const _Title(),
              SizedBox(height: 4.5 * s),
              _Subtitle(text: section.title),
              SizedBox(height: 11.5 * s),
              Align(
                alignment: Alignment.centerLeft,
                child: Visibility(
                  // The menu is this button's glass once it opens, so the
                  // button steps out of the way rather than sitting under it
                  // and doubling both the lens and the glyph. Its space is
                  // kept, so nothing below moves.
                  visible: !_menuOpen,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: GlassToolButton(
                    size: button,
                    onTap: _openMenu,
                    semanticLabel: 'Detallar',
                    glyph: DatabaseMenuGlyph(button: button),
                  ),
                ),
              ),
              SizedBox(height: 15 * s),
              Expanded(
                child: section == DatabaseSection.overview
                    ? _Overview(
                        controller: database,
                        bottomReserve: widget.bottomReserve,
                      )
                    : _NotBuiltYet(bottomReserve: widget.bottomReserve),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Baza',
      maxLines: 1,
      style: TextStyle(
        color: kGlassInk,
        // CalSans, like every page title in the app. Larger than the task
        // list's, because this design draws it larger.
        fontFamily: 'CalSans',
        fontSize: 44 * databaseScale(context),
        height: 1.08,
        letterSpacing: -1.2,
      ),
    );
  }
}

/// The page on screen, under `Baza`. Changes with the menu.
class _Subtitle extends StatelessWidget {
  const _Subtitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
        alignment: Alignment.centerLeft,
        children: <Widget>[...previous, ?current],
      ),
      child: Align(
        key: ValueKey<String>(text),
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: kGlassInk,
              fontFamily: 'CalSans',
              fontSize: 25 * databaseScale(context),
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// `Əsas panel`: the ten figures, one row each.
class _Overview extends StatelessWidget {
  const _Overview({required this.controller, required this.bottomReserve});

  final DatabaseController controller;
  final double bottomReserve;

  @override
  Widget build(BuildContext context) {
    final double s = databaseScale(context);
    final double height = 52.5 * s;
    final double gap = 10.5 * s;
    final String? error = controller.error;

    return RefreshIndicator(
      onRefresh: controller.load,
      edgeOffset: scaled(context, 8),
      color: kGlassInk,
      backgroundColor: const Color(0xE6FFFFFF),
      // One backdrop group for the whole list: every row's blur samples the
      // same snapshot of what is behind it, which is one filter pass per frame
      // instead of ten.
      child: BackdropGroup(
        child: ListView(
          padding: EdgeInsets.only(bottom: bottomReserve),
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            if (error != null)
              Padding(
                padding: EdgeInsets.only(bottom: gap),
                child: _Failure(message: error, onRetry: controller.load),
              ),
            for (final DatabaseMetric metric in DatabaseMetric.values)
              Padding(
                padding: EdgeInsets.only(top: metric.index == 0 ? 0 : gap),
                child: DatabaseOverviewRow(
                  metric: metric,
                  value: _written(metric, controller.overview.valueOf(metric)),
                  height: height,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String? _written(DatabaseMetric metric, num? value) {
    if (value == null) return null;
    return metric.isMoney
        ? formatMoney(value.toDouble())
        : formatCount(value.toInt());
  }
}

/// Why nothing came back, above the rows it left empty.
///
/// The rows stay: ten dashes under one sentence say "not known" more plainly
/// than a blank page does, and pulling the list down retries as well as the
/// button.
class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        scaled(context, 16),
        scaled(context, 6),
        scaled(context, 6),
        scaled(context, 6),
      ),
      decoration: ShapeDecoration(
        color: const Color(0xF0FFFFFF),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(scaled(context, 16)),
        ),
        shadows: kGlassLift,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: scaled(context, 13),
                height: 1.3,
                color: kGlassInk,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Yenidən cəhd et')),
        ],
      ),
    );
  }
}

/// Every page but `Əsas panel`, until its own design lands.
class _NotBuiltYet extends StatelessWidget {
  const _NotBuiltYet({required this.bottomReserve});

  final double bottomReserve;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomReserve),
      child: Center(
        child: Text(
          'Bu bölmə hazırlanır.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: kGlassInkMuted,
            fontFamily: 'Poppins',
            fontSize: scaled(context, 14),
            height: 1.3,
          ),
        ),
      ),
    );
  }
}
