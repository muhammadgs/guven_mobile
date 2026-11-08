import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/layout.dart';
import '../../attendance/application/attendance_controller.dart';
import '../../attendance/data/attendance_api.dart';
import '../../attendance/presentation/attendance_metrics.dart';
import '../../attendance/presentation/attendance_reminder.dart';
import '../../attendance/presentation/widgets/attendance_card.dart';
import '../../attendance/presentation/widgets/profile_button.dart';
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
  const HomeScreen({
    super.key,
    required this.bottomReserve,
    this.active = true,
    this.attendance,
  });

  /// Vertical space the nav bar occupies, which this screen must keep clear.
  /// Passed in rather than measured, because the bar floats over the page
  /// instead of sitting under it.
  final double bottomReserve;

  /// Whether this is the tab on view. The attendance reminders wait for it.
  final bool active;

  /// Injected by tests; otherwise built from the session.
  final AttendanceController? attendance;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  HomeController? _controller;
  AttendanceController? _attendance;
  AttendanceReminder? _reminder;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The site looks every 30 seconds; so does this, against the clock
    // only — the network is asked once a reminder is actually due.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) => _remind());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final SessionController session = SessionScope.read(context);
    _controller = HomeController(session)..load();
    final AttendanceController attendance =
        widget.attendance ??
        AttendanceController(AttendanceApi(session.client));
    _attendance = attendance;
    _reminder = AttendanceReminder(attendance);
    attendance.refresh().then((_) => _remind());
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _remind();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _attendance?.refresh().then((_) => _remind());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    _controller?.dispose();
    if (widget.attendance == null) _attendance?.dispose();
    super.dispose();
  }

  /// Only over the home screen itself: not over another tab, and not over
  /// a card or a sheet someone is already busy with.
  bool _canRemind() =>
      mounted && widget.active && (ModalRoute.of(context)?.isCurrent ?? true);

  void _remind() {
    if (!mounted) return;
    _reminder?.check(context, _canRemind);
  }

  Future<void> _openProfile(Rect button) async {
    final AttendanceController? attendance = _attendance;
    if (attendance == null) return;
    await openAttendanceCard(
      context,
      button: button,
      controller: attendance,
      user: SessionScope.read(context).user,
      bottomReserve: widget.bottomReserve,
    );
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

        final double side = scaled(context, 24);
        final AttendanceMetrics m = AttendanceMetrics.of(context);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            0,
            safe.top + scaled(context, 10),
            0,
            widget.bottomReserve,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // The profile button sits further out than the pills — its
              // left edge is the profile card's, which the design pins
              // 11.5pt from the screen's — and the greeting follows it,
              // centred on the same line.
              Row(
                children: <Widget>[
                  SizedBox(width: m.profileLeft),
                  ProfileButton(onOpen: _openProfile),
                  SizedBox(width: m.greetingGap),
                  Expanded(
                    child: _Greeting(
                      name: session.user?.greetingName ?? 'İstifadəçi',
                    ),
                  ),
                  SizedBox(width: side),
                ],
              ),
              SizedBox(height: scaled(context, 22)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: side),
                child: _StatColumn(
                  snapshot: data,
                  pending: pending,
                  height: scaled(context, 58),
                  gap: scaled(context, 13),
                ),
              ),
              SizedBox(height: scaled(context, 18)),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: side),
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
    // Left-aligned beside the profile button, as the design sets it.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        'Salam, $name',
        textAlign: TextAlign.left,
        maxLines: 1,
        softWrap: false,
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
