import 'package:flutter/material.dart';

import '../../../shared/layout.dart';
import '../../auth/application/session_controller.dart';
import '../application/home_controller.dart';
import '../domain/home_snapshot.dart';
import 'widgets/activity_panel.dart';
import 'widgets/home_glass.dart';
import 'widgets/stat_pill.dart';

/// Əsas səhifə — the same screen for an owner and for an employee.
///
/// Both roles get one dashboard on the website too (`owner/owp.html` and
/// `worker/wp.html` share a `dashboard.js`), and the numbers are all scoped by
/// the caller's own company, so there is nothing role-specific left to branch
/// on here.
///
/// Nothing in this screen scrolls except the activity list: the greeting and
/// the three counts are the fixed frame, and the tray takes whatever height is
/// left over.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.bottomReserve});

  /// Vertical space the nav bar occupies, which this screen must keep clear.
  /// Passed in rather than measured, because the bar floats over the page
  /// instead of sitting under it.
  final double bottomReserve;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    _controller = HomeController(SessionScope.read(context))..load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SessionController session = SessionScope.of(context);
    final HomeController home = _controller!;
    final EdgeInsets safe = MediaQuery.paddingOf(context);

    return ListenableBuilder(
      listenable: home,
      builder: (BuildContext context, _) {
        final HomeSnapshot data = home.snapshot;
        // Every count is unknown until the first load lands, and the three
        // pills say so together rather than one at a time.
        final bool pending = !home.hasLoaded;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            scaled(context, 24),
            safe.top + scaled(context, 10),
            scaled(context, 24),
            widget.bottomReserve,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Greeting(name: session.user?.greetingName ?? 'İstifadəçi'),
              SizedBox(height: scaled(context, 22)),
              _StatColumn(
                snapshot: data,
                pending: pending,
                height: scaled(context, 58),
                gap: scaled(context, 13),
              ),
              SizedBox(height: scaled(context, 18)),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: home.load,
                  edgeOffset: scaled(context, 8),
                  color: kGlassInk,
                  backgroundColor: const Color(0xE6FFFFFF),
                  child: ActivityPanel(
                    activities: data.activities,
                    loading: home.isLoading && !home.hasLoaded,
                    error: home.error,
                    onRetry: home.load,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    // One line, whatever the name. `Salam, Ə.` and `Salam, Muhəmməd` are the
    // same sentence and should look like it, so a long one is scaled down
    // rather than wrapped or cut — an ellipsis in the middle of someone's
    // name is worse than a slightly smaller greeting.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        'Salam, $name',
        textAlign: TextAlign.center,
        maxLines: 1,
        softWrap: false,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: kGlassInk,
          // The one CalSans left in the signed-in app. Everything else is
          // Poppins, which is what makes this read as the page's title
          // rather than as another large label.
          fontFamily: 'CalSans',
          fontSize: responsive(context, factor: 0.092, min: 30, max: 42),
          height: 1.08,
          letterSpacing: -1.0,
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.snapshot,
    required this.pending,
    required this.height,
    required this.gap,
  });

  final HomeSnapshot snapshot;
  final bool pending;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return AppGlassLayer(
      style: kStatPillGlass,
      child: Column(
        children: <Widget>[
          StatPill(
            label: 'Əməkdaşlarım',
            value: snapshot.employeeCount,
            height: height,
            pending: pending,
          ),
          SizedBox(height: gap),
          StatPill(
            label: 'Şirkətlərim',
            value: snapshot.companyCount,
            height: height,
            pending: pending,
          ),
          SizedBox(height: gap),
          StatPill(
            label: 'Aktiv tapşırıqlar',
            value: snapshot.activeTaskCount,
            height: height,
            pending: pending,
          ),
        ],
      ),
    );
  }
}
