/// The profile card: who you are, where today stands, and the history.
///
/// It grows out of the profile button the way `Baza`'s and `Tapşırıqlar`'
/// filters grow out of theirs — one surface that travels from the button's
/// rect to its own (`glass_morph.dart`'s choreography) — but it is plain
/// white, not glass, as the design draws it. Because nothing inside it is a
/// lens, its contents may fade with an ordinary `Opacity`.
library;

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../shared/motion/glass_morph.dart';
import '../../../auth/domain/auth_user.dart';
import '../../application/attendance_controller.dart';
import '../../domain/attendance.dart';
import '../attendance_metrics.dart';
import '../attendance_style.dart';
import 'attendance_prompt.dart';

const Duration _kOpen = Duration(milliseconds: 520);
const Duration _kClose = Duration(milliseconds: 340);
const Duration _kHistory = Duration(milliseconds: 460);

/// The glyph on the profile button and, for the first half of the flight,
/// on the avatar it becomes.
const String kAccountIcon =
    'assets/images/icons/setting_icons/account_icon.svg';

/// Opens the card out of the profile button at [button] (global rect).
Future<void> openAttendanceCard(
  BuildContext context, {
  required Rect button,
  required AttendanceController controller,
  required AuthUser? user,
  required double bottomReserve,
}) async {
  final GlassMorphRoute<void> route = GlassMorphRoute<void>(
    sourceRect: button,
    sourceRadius: button.shortestSide / 2,
    duration: _kOpen,
    reverseDuration: _kClose,
    opaque: false,
    builder: (_) => AttendanceCard(
      controller: controller,
      user: user,
      bottomReserve: bottomReserve,
    ),
  );
  await Navigator.of(context).push<void>(route);
  await route.completed;
}

class AttendanceCard extends StatefulWidget {
  const AttendanceCard({
    super.key,
    required this.controller,
    required this.user,
    required this.bottomReserve,
  });

  final AttendanceController controller;
  final AuthUser? user;
  final double bottomReserve;

  @override
  State<AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends State<AttendanceCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _history = AnimationController(
    vsync: this,
    duration: _kHistory,
    reverseDuration: const Duration(milliseconds: 380),
  );

  final GlobalKey _actionKey = GlobalKey();

  /// A failure to show in the status line's place for a few seconds — there
  /// is no `Scaffold` to put a snack bar on (`no-scaffold-in-this-app`).
  String? _flash;
  int _flashToken = 0;

  AttendanceController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
    // The card is the moment someone looks: make sure it is today's truth.
    _c.refresh();
  }

  @override
  void dispose() {
    _c.removeListener(_changed);
    _history.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _close() {
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _toggleHistory() {
    HapticFeedback.selectionClick();
    if (_history.value > 0.5 || _history.status == AnimationStatus.forward) {
      _history.reverse();
    } else {
      _history.forward();
      _c.refresh();
    }
  }

  Future<void> _pressAction(AttendanceKind kind) async {
    if (_c.isBusy) return;
    HapticFeedback.selectionClick();
    if (AttendanceRules.needsReason(kind, _c.baku)) {
      final RenderBox? box =
          _actionKey.currentContext?.findRenderObject() as RenderBox?;
      final Rect? source = box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size;
      await showAttendancePrompt(
        context,
        controller: _c,
        kind: kind,
        start: PromptStage.reason,
        source: source,
        sourceRadius: (source?.height ?? 0) / 2,
        overCard: true,
      );
      return;
    }
    final String? error = await _c.press(kind, '');
    if (error != null) _showFlash(error);
  }

  Future<void> _showFlash(String message) async {
    final int token = ++_flashToken;
    if (!mounted) return;
    setState(() => _flash = message);
    await Future<void>.delayed(const Duration(seconds: 4));
    if (mounted && token == _flashToken) setState(() => _flash = null);
  }

  @override
  Widget build(BuildContext context) {
    final AttendanceMetrics m = AttendanceMetrics.of(context);
    final GlassMorph? morph = GlassMorph.maybeOf(context);
    final Animation<double> flight =
        morph?.progress ?? kAlwaysCompleteAnimation;
    final Rect button =
        morph?.sourceRect ??
        Rect.fromLTWH(
          m.profileLeft,
          MediaQuery.paddingOf(context).top + m.profileDiameter,
          m.profileDiameter,
          m.profileDiameter,
        );

    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[flight, _history]),
        builder: (BuildContext context, _) {
          final double h = _history.value;
          final double cardTop = m.cardRectFor(button, 0).top;
          final double panel = m.panelHeight(
            _c.history.events.map((AttendanceEvent e) => e.note != null),
            cardTop: cardTop,
            floor: m.cardFloor(widget.bottomReserve),
          );
          final double height = lerpDouble(
            m.cardClosedHeight,
            m.cardOpenHeight(panel),
            Curves.easeInOutCubic.transform(h),
          )!;
          final Rect rest = m.cardRectFor(button, height);

          final GlassMorphFrame frame = morph == null
              ? GlassMorphFrame.settled(rest, m.cardRadius)
              : resolveGlassMorph(
                  progress: flight,
                  from: button,
                  fromRadius: morph.sourceRadius,
                  to: rest,
                  toRadius: m.cardRadius,
                );

          // White arrives fast: by a third of the way the button is gone
          // under it, so the glass button never shows through a half-made
          // card.
          final double white = (frame.blend / 0.32).clamp(0.0, 1.0);

          // The avatar travels on its own, from the button's disc to its
          // place on the card.
          final Rect avatarRest = Rect.fromLTWH(
            rest.left + m.avatarLeft,
            rest.top + m.avatarTop,
            m.avatarDiameter,
            m.avatarDiameter,
          );
          final double travel = frame.isSettled
              ? 1
              : (frame.rect.width - button.width) /
                    math.max(1, rest.width - button.width);
          final Rect avatar = Rect.lerp(
            button,
            avatarRest,
            travel.clamp(0.0, 1.05),
          )!;

          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: AttendanceScrim(amount: frame.blend, onTap: _close),
              ),
              Positioned.fromRect(
                rect: frame.rect,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: kAttendanceCard.withValues(alpha: white),
                    borderRadius: BorderRadius.circular(frame.radius),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Color.fromRGBO(16, 24, 38, 0.16 * white),
                        blurRadius: 34,
                        spreadRadius: -8,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(frame.radius),
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minWidth: rest.width,
                      maxWidth: rest.width,
                      minHeight: height,
                      maxHeight: height,
                      child: Opacity(
                        opacity: frame.targetOpacity,
                        child: _CardBody(
                          metrics: m,
                          controller: _c,
                          user: widget.user,
                          history: h,
                          panelHeight: panel,
                          flash: _flash,
                          actionKey: _actionKey,
                          onAction: _pressAction,
                          onHistory: _toggleHistory,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: avatar,
                child: IgnorePointer(
                  child: _Avatar(
                    initials: initialsOf(widget.user),
                    fill: white,
                    glyph: frame.sourceOpacity,
                    letters: frame.targetOpacity,
                    metrics: m,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// `MQ` for Məhəmməd Qasımov. Azerbaijani capitals: `i` is `İ`.
String initialsOf(AuthUser? user) {
  String first(String? word) {
    final String w = (word ?? '').trim();
    if (w.isEmpty) return '';
    final String c = w.characters.first;
    return c == 'i' ? 'İ' : c.toUpperCase();
  }

  final String out = first(user?.firstName) + first(user?.lastName);
  if (out.isNotEmpty) return out;
  return first(user?.greetingName);
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.initials,
    required this.fill,
    required this.glyph,
    required this.letters,
    required this.metrics,
  });

  final String initials;

  /// 0 while it is still the glass button underneath, 1 once it is the
  /// card's grey disc.
  final double fill;
  final double glyph;
  final double letters;
  final AttendanceMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final AttendanceMetrics m = metrics;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kAttendanceAvatar.withValues(alpha: fill),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (glyph > 0)
            Opacity(
              opacity: glyph,
              child: SvgPicture.asset(
                kAccountIcon,
                width: m.profileIcon,
                height: m.profileIcon,
              ),
            ),
          if (letters > 0)
            Opacity(
              opacity: letters,
              child: Padding(
                padding: EdgeInsets.all(m.avatarDiameter * 0.12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    initials,
                    maxLines: 1,
                    style: attendanceText(
                      m.type(AttendanceMetrics.initialsSize),
                      line: 1.2,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Everything printed on the card, laid out at rest in card coordinates.
class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.metrics,
    required this.controller,
    required this.user,
    required this.history,
    required this.panelHeight,
    required this.flash,
    required this.actionKey,
    required this.onAction,
    required this.onHistory,
  });

  final AttendanceMetrics metrics;
  final AttendanceController controller;
  final AuthUser? user;

  /// 0 shut, 1 the history fully open.
  final double history;
  final double panelHeight;
  final String? flash;
  final GlobalKey actionKey;
  final ValueChanged<AttendanceKind> onAction;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final AttendanceMetrics m = metrics;
    final double textWidth = m.cardWidth - m.nameLeft - m.textRight;
    final String name = (user?.fullName.isNotEmpty ?? false)
        ? user!.fullName
        : (user?.greetingName ?? 'İstifadəçi');
    final String company = user?.companyName ?? '';

    final AttendanceKind? kind = controller.load == AttendanceLoad.ready
        ? controller.nextKind
        : null;
    final bool hasAction = kind != null;

    // The choreography of opening the history, each part on its own beat:
    // the action button leaves first, `Tarixçə` slides into its place and
    // widens, and the panel unfolds from under it.
    final double leave = Curves.easeIn.transform((history / 0.4).clamp(0, 1));
    final double slide = Curves.easeInOutCubic.transform(
      (history / 0.75).clamp(0.0, 1.0),
    );
    final double unfold = Curves.easeOutCubic.transform(
      ((history - 0.12) / 0.88).clamp(0.0, 1.0),
    );
    final double rows = Curves.easeOut.transform(
      ((history - 0.5) / 0.5).clamp(0.0, 1.0),
    );

    final TextStyle body = attendanceText(m.type(AttendanceMetrics.bodySize));
    final double hideWidth =
        _textWidth(context, 'Tarixçəni gizlət', body) + 2 * m.hideButtonPad;

    final double historyLeftShut = m.historyButtonLeft(withAction: hasAction);
    final double historyLeft = lerpDouble(historyLeftShut, m.panelLeft, slide)!;
    final double historyWidth = lerpDouble(
      m.buttonWidth,
      math.max(m.buttonWidth, hideWidth),
      slide,
    )!;

    final Rect panelRect = Rect.fromLTWH(
      lerpDouble(historyLeftShut, m.panelLeft, slide)!,
      m.buttonsTop,
      lerpDouble(m.buttonWidth, m.panelWidth, unfold)!,
      lerpDouble(m.buttonHeight, panelHeight, unfold)!,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        // Name and company.
        Positioned(
          left: m.nameLeft,
          top: m.nameTop,
          width: textWidth,
          child: _OneLine(
            text: name,
            style: attendanceText(
              m.type(AttendanceMetrics.nameSize),
              line: AttendanceMetrics.nameLine,
              family: 'CalSans',
              tracking: AttendanceMetrics.nameTracking * m.scale,
            ),
          ),
        ),
        if (company.isNotEmpty)
          Positioned(
            left: m.nameLeft,
            top: m.companyTop,
            width: textWidth,
            child: _OneLine(
              text: company,
              style: attendanceText(
                m.type(AttendanceMetrics.companySize),
                tracking: AttendanceMetrics.companyTracking * m.scale,
              ),
            ),
          ),

        // Dəvamiyyət: …
        Positioned(
          left: m.statusLeft,
          top: m.statusTop,
          right: m.textRight,
          child: _StatusLine(controller: controller, flash: flash, style: body),
        ),

        // The history panel, under the buttons.
        if (history > 0)
          Positioned.fromRect(
            rect: panelRect,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: kHistoryPanel.withValues(alpha: unfold),
                borderRadius: BorderRadius.circular(
                  lerpDouble(m.buttonHeight / 2, m.panelRadius, unfold)!,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  lerpDouble(m.buttonHeight / 2, m.panelRadius, unfold)!,
                ),
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: m.panelWidth,
                  maxWidth: m.panelWidth,
                  minHeight: panelHeight,
                  maxHeight: panelHeight,
                  child: Opacity(
                    opacity: rows,
                    child: Padding(
                      padding: EdgeInsets.only(top: m.rowsTop),
                      child: _HistoryRows(metrics: m, controller: controller),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // The action button — leaves as the history opens.
        if (hasAction && leave < 1)
          Positioned(
            left: m.actionLeft,
            top: m.buttonsTop,
            width: m.buttonWidth,
            height: m.buttonHeight,
            child: IgnorePointer(
              ignoring: history > 0,
              child: Opacity(
                opacity: 1 - leave,
                child: Transform.scale(
                  scale: 1 - 0.18 * leave,
                  child: _FlatButton(
                    key: actionKey,
                    metrics: m,
                    fill: fillFor(kind),
                    busy: controller.pressing == kind,
                    onTap: () => onAction(kind),
                    child: _Label(kind.label, style: body),
                  ),
                ),
              ),
            ),
          ),

        // Tarixçə ⇄ Tarixçəni gizlət.
        Positioned(
          left: historyLeft,
          top: m.buttonsTop,
          width: historyWidth,
          height: m.buttonHeight,
          child: _FlatButton(
            metrics: m,
            fill: kHistoryFill,
            onTap: onHistory,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Opacity(
                  opacity: (1 - slide * 2.2).clamp(0.0, 1.0),
                  child: _Label('Tarixçə', style: body),
                ),
                Opacity(
                  opacity: ((slide - 0.45) / 0.55).clamp(0.0, 1.0),
                  child: _Label('Tarixçəni gizlət', style: body),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static double _textWidth(BuildContext context, String text, TextStyle style) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final double width = painter.width;
    painter.dispose();
    return width;
  }
}

/// A name never wraps or gets an ellipsis: it shrinks to fit.
class _OneLine extends StatelessWidget {
  const _OneLine({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(text, maxLines: 1, softWrap: false, style: style),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          style: style.copyWith(height: 1.2),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.controller,
    required this.flash,
    required this.style,
  });

  final AttendanceController controller;
  final String? flash;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final (String, Color) state = switch (controller.load) {
      AttendanceLoad.loading => ('Yüklənir…', kStatusMuted),
      AttendanceLoad.failed => ('Yüklənmədi', kStatusMuted),
      AttendanceLoad.ready => switch (controller.day) {
        AttendanceDay.notEntered => ('Giriş edilməyib', kStatusAbsent),
        AttendanceDay.atWork => ('Giriş edilib', kStatusPresent),
        AttendanceDay.finished => ('Çıxış edilib', kHistoryExit),
      },
    };
    final String? message = flash;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
        alignment: Alignment.centerLeft,
        children: <Widget>[...previous, ?current],
      ),
      child: message != null
          ? FittedBox(
              key: ValueKey<String>('flash:$message'),
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                message,
                maxLines: 1,
                style: style.copyWith(color: kStatusAbsent),
              ),
            )
          : FittedBox(
              key: ValueKey<String>(state.$1),
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    const TextSpan(text: 'Dəvamiyyət: '),
                    TextSpan(
                      text: state.$1,
                      style: TextStyle(color: state.$2),
                    ),
                  ],
                ),
                maxLines: 1,
                style: style,
              ),
            ),
    );
  }
}

/// A flat capsule on the card: a fill that darkens a shade under the finger.
class _FlatButton extends StatefulWidget {
  const _FlatButton({
    super.key,
    required this.metrics,
    required this.fill,
    required this.onTap,
    required this.child,
    this.busy = false,
  });

  final AttendanceMetrics metrics;
  final Color fill;
  final VoidCallback onTap;
  final Widget child;
  final bool busy;

  @override
  State<_FlatButton> createState() => _FlatButtonState();
}

class _FlatButtonState extends State<_FlatButton> {
  bool _down = false;

  void _press(bool down) {
    if (_down == down) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final double h = widget.metrics.buttonHeight;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press(true),
      onTapUp: (_) => _press(false),
      onTapCancel: () => _press(false),
      onTap: widget.busy ? null : widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _down
                ? Color.alphaBlend(const Color(0x14000000), widget.fill)
                : widget.fill,
            borderRadius: BorderRadius.circular(h / 2),
          ),
          alignment: Alignment.center,
          child: widget.busy
              ? SizedBox(
                  width: h * 0.46,
                  height: h * 0.46,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(kAttendanceInk),
                  ),
                )
              : widget.child,
        ),
      ),
    );
  }
}

/// Every press of either button, newest first, with its reason under it.
class _HistoryRows extends StatelessWidget {
  const _HistoryRows({required this.metrics, required this.controller});

  final AttendanceMetrics metrics;
  final AttendanceController controller;

  @override
  Widget build(BuildContext context) {
    final AttendanceMetrics m = metrics;
    final List<AttendanceEvent> events = controller.history.events;
    final TextStyle label = attendanceText(
      m.type(AttendanceMetrics.bodySize),
      line: AttendanceMetrics.rowLabelLine,
    );
    final TextStyle note = attendanceText(
      m.type(AttendanceMetrics.noteSize),
      line: AttendanceMetrics.rowNoteLine,
    );

    if (events.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(
          left: m.rowInsetLeft,
          right: m.rowInsetRight,
          bottom: m.rowsBottomPad,
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(
            controller.load == AttendanceLoad.failed
                ? 'Tarixçə yüklənmədi'
                : controller.load == AttendanceLoad.loading
                ? 'Yüklənir…'
                : 'Hələ giriş/çıxış yoxdur',
            style: note.copyWith(color: kStatusMuted),
          ),
        ),
      );
    }

    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(overscroll: false),
      child: ListView.separated(
        padding: EdgeInsets.only(bottom: m.rowsBottomPad),
        physics: const ClampingScrollPhysics(),
        itemCount: events.length,
        separatorBuilder: (BuildContext context, int index) => Padding(
          padding: EdgeInsets.only(
            top: m.dividerGapAbove,
            bottom: m.dividerGapBelow,
            left: m.dividerInsetLeft,
            right: m.dividerInsetRight,
          ),
          child: SizedBox(
            height: m.dividerThickness,
            child: const ColoredBox(color: kAttendanceInk),
          ),
        ),
        itemBuilder: (BuildContext context, int index) {
          final AttendanceEvent event = events[index];
          final bool entry = event.kind == AttendanceKind.entry;
          return Padding(
            padding: EdgeInsets.only(
              left: m.rowInsetLeft,
              right: m.rowInsetRight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      event.kind.label,
                      style: label.copyWith(
                        color: entry ? kHistoryEntry : kHistoryExit,
                      ),
                    ),
                    const Spacer(),
                    Text(event.shown, style: label),
                  ],
                ),
                if (event.note != null)
                  Text(
                    event.note!,
                    style: note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
