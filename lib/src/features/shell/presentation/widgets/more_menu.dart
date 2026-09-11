import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../home/presentation/widgets/home_glass.dart';
import '../../domain/shell_destination.dart';
import '../more_menu_metrics.dart';

/// Pushed back behind the fan: the screen dims a little and goes soft, so the
/// white buttons read as the only thing in front of it. Lighter than the task
/// sheets' scrim — the fan is a shortcut, not a page.
const Color kMoreMenuScrim = Color(0x5C070C14);
const double kMoreMenuBlur = 12;

/// The `Daha çox` fan: the page buttons that are not in the bar, on arcs over
/// it, in front of a dimmed and blurred screen.
///
/// Everything is driven by one [open] animation, 0 shut and 1 open. Each
/// button takes its own slice of it, a [stagger] after the one before, so they
/// leave `Daha çox` one at a time and in order — and, played backwards, come
/// home in the reverse order.
///
/// Nothing here is glass, and nothing here may become glass without looking
/// again at the fades: the buttons and the scrim both animate an `Opacity`,
/// which is only safe because there is no lens underneath one
/// (`backdrop-filter-black-flash`).
class MoreMenu extends StatelessWidget {
  const MoreMenu({
    super.key,
    required this.metrics,
    required this.open,
    required this.items,
    required this.lifted,
    required this.interactive,
    required this.onChoose,
    required this.onLift,
    required this.onDismiss,
  });

  /// Between one button leaving and the next.
  static const Duration stagger = Duration(milliseconds: 32);

  /// One button's flight from `Daha çox` to its place.
  static const Duration flight = Duration(milliseconds: 340);

  /// How long the whole fan takes to open: the last button leaves
  /// `count - 1` staggers after the first, and flies for as long as they all
  /// do.
  static Duration openDuration(int count) =>
      stagger * math.max(0, count - 1) + flight;

  /// Shutting is quicker than opening — the user already knows what is there.
  static const Duration closeDuration = Duration(milliseconds: 280);

  final MoreMenuMetrics metrics;
  final Animation<double> open;

  /// The fan's pages, in slot order: outer arc left to right, then the inner.
  final List<ShellDestination> items;

  /// The page being dragged, if it is in the fan. Its slot is drawn empty.
  final ShellDestination? lifted;

  /// False while shutting, so a tap during the flight home reaches whatever it
  /// lands on instead of an invisible button.
  final bool interactive;

  final ValueChanged<ShellDestination> onChoose;

  /// A long press on a button: the shell takes the drag over from here.
  final void Function(ShellDestination item, Offset globalPosition) onLift;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: open,
      builder: (BuildContext context, _) {
        final double t = open.value;
        if (t <= 0 && open.status == AnimationStatus.dismissed) {
          return const SizedBox.shrink();
        }
        final double scrim = Curves.easeOut.transform(
          (t / 0.45).clamp(0.0, 1.0),
        );
        final bool settled = open.status == AnimationStatus.completed;

        return IgnorePointer(
          ignoring: !interactive,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
                // The blur and the dimming are animated on the filter and the
                // colour themselves. An `Opacity` above a `BackdropFilter`
                // would hand it an empty layer to sample, and it would blur
                // nothing.
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: kMoreMenuBlur * scrim,
                    sigmaY: kMoreMenuBlur * scrim,
                  ),
                  child: ColoredBox(
                    color: kMoreMenuScrim.withValues(
                      alpha: kMoreMenuScrim.a * scrim,
                    ),
                  ),
                ),
              ),
              for (int i = 0; i < items.length; i++)
                _MoreBubble(
                  key: ValueKey<ShellDestination>(items[i]),
                  metrics: metrics,
                  item: items[i],
                  slot: metrics.center(i),
                  progress: _progress(t, i),
                  empty: items[i] == lifted,
                  popIn: settled,
                  onTap: () => onChoose(items[i]),
                  onLift: (Offset global) => onLift(items[i], global),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Button [index]'s own slice of [t]: it starts [stagger] × [index] in.
  double _progress(double t, int index) {
    final double total = openDuration(items.length).inMicroseconds.toDouble();
    final double begin = stagger.inMicroseconds * index / total;
    final double end =
        (stagger.inMicroseconds * index + flight.inMicroseconds) / total;
    return ((t - begin) / (end - begin)).clamp(0.0, 1.0);
  }
}

/// One page button: a white disc with the page's glyph, and its name under it.
class _MoreBubble extends StatelessWidget {
  const _MoreBubble({
    super.key,
    required this.metrics,
    required this.item,
    required this.slot,
    required this.progress,
    required this.empty,
    required this.popIn,
    required this.onTap,
    required this.onLift,
  });

  final MoreMenuMetrics metrics;
  final ShellDestination item;

  /// Where the button lives while the fan is open.
  final Offset slot;

  /// 0 still inside `Daha çox`, 1 in its slot.
  final double progress;

  /// Lifted out by a drag: the slot is drawn as an outline, waiting.
  final bool empty;
  final bool popIn;
  final VoidCallback onTap;
  final ValueChanged<Offset> onLift;

  /// A button that changes slot mid-drag slides over rather than jumping.
  static const Duration _reflow = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    final double disc = metrics.bubble;
    final double width = math.max(metrics.labelWidth, disc);
    final double height = disc + metrics.labelGap + metrics.labelHeight;
    // The disc is in the top of the box; it scales about its own centre, not
    // the box's.
    final Alignment discCenter = Alignment(0, disc / height - 1);

    return TweenAnimationBuilder<Offset>(
      tween: Tween<Offset>(end: slot),
      duration: _reflow,
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, Offset home, Widget? child) {
        final Offset center = _inFlight(home);
        return Positioned(
          left: center.dx - width / 2,
          top: center.dy - disc / 2,
          width: width,
          height: height,
          child: child!,
        );
      },
      // Read once, when this button first turns up: one that arrives while
      // the fan is already open — traded in from the bar mid-drag — pops into
      // its slot instead of appearing. It sits above the empty/full switch,
      // so a button that was only waiting for its dragged disc to land does
      // not pop a second time when the disc does.
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: popIn ? 0.5 : 1, end: 1),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        builder: (BuildContext context, double pop, Widget? child) {
          return Transform.scale(
            scale: pop,
            alignment: discCenter,
            child: child,
          );
        },
        child: empty
            ? _placeholder(disc)
            : _button(context, disc, discCenter),
      ),
    );
  }

  /// The button's centre [progress] of the way out of `Daha çox`.
  ///
  /// It swings out around the arcs' pivot rather than flying straight: its
  /// distance from the pivot overshoots and settles, its angle eases in, so
  /// the buttons rise out of the bar and fan apart as they go.
  Offset _inFlight(Offset home) {
    if (progress >= 1) return home;
    final Offset pivot = metrics.pivot;
    final Offset origin = metrics.origin;
    final Offset to = home - pivot;
    final double toRadius = to.distance;
    final double toAngle = math.atan2(to.dx, -to.dy);
    final double fromRadius = (origin - pivot).distance;
    final double radius = lerpDouble(
      fromRadius,
      toRadius,
      Curves.easeOutBack.transform(progress),
    )!;
    final double angle = toAngle * Curves.easeOutCubic.transform(progress);
    return pivot + Offset(radius * math.sin(angle), -radius * math.cos(angle));
  }

  Widget _button(BuildContext context, double disc, Alignment discCenter) {
    final double p = progress;
    final double scale = lerpDouble(
      0.35,
      1,
      Curves.easeOutBack.transform(p),
    )!.clamp(0.0, 2.0);

    return _PressScale(
      onTap: onTap,
      onLift: onLift,
      child: Transform.scale(
        scale: scale,
        alignment: discCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Opacity(
              opacity: (p / 0.3).clamp(0.0, 1.0),
              child: MoreMenuDisc(item: item, metrics: metrics),
            ),
            SizedBox(height: metrics.labelGap),
            Opacity(
              opacity: ((p - 0.45) / 0.55).clamp(0.0, 1.0),
              child: SizedBox(
                width: metrics.labelWidth,
                height: metrics.labelHeight,
                // Names are never cut in this app. A larger system font makes
                // the longest one — `Rəsmi Qurumlar` — a little smaller
                // instead.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.title,
                    maxLines: 1,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      fontSize: metrics.labelSize,
                      height: MoreMenuMetrics.kLabelLineHeight,
                      // Explicit, not the theme's 0.25: the arcs were fitted
                      // to names measured without it.
                      letterSpacing: 0,
                      shadows: const <Shadow>[
                        Shadow(color: Color(0x59000000), blurRadius: 6),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(double disc) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: disc,
        height: disc,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.55),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

/// The white disc a page button is drawn on — also what the finger carries
/// during a drag, so the thing that is lifted and the thing that lands look
/// the same.
class MoreMenuDisc extends StatelessWidget {
  const MoreMenuDisc({
    super.key,
    required this.item,
    required this.metrics,
    this.lifted = false,
  });

  final ShellDestination item;
  final MoreMenuMetrics metrics;
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final double disc = metrics.bubble;
    return Container(
      width: disc,
      height: disc,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(lifted ? 0x33101826 : 0x1A101826),
            blurRadius: lifted ? 22 : 12,
            offset: Offset(0, lifted ? 10 : 4),
          ),
        ],
      ),
      child: SvgPicture.asset(
        item.icon,
        width: metrics.icon,
        height: metrics.icon,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(kGlassInk, BlendMode.srcIn),
      ),
    );
  }
}

/// Sinks a little under the finger, and hands a long press to the shell.
class _PressScale extends StatefulWidget {
  const _PressScale({
    required this.onTap,
    required this.onLift,
    required this.child,
  });

  final VoidCallback onTap;
  final ValueChanged<Offset> onLift;
  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      onLongPressStart: (LongPressStartDetails details) {
        _set(false);
        widget.onLift(details.globalPosition);
      },
      child: AnimatedScale(
        scale: _down ? 0.92 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
