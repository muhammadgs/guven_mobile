import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../shared/layout.dart';
import '../../domain/activity.dart';
import 'home_glass.dart';

/// The "son aktivliklər" tray: one large pane of glass with a scrolling column
/// of smaller ones inside it.
class ActivityPanel extends StatelessWidget {
  const ActivityPanel({
    super.key,
    required this.activities,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final List<Activity> activities;

  /// True before the first load has landed. A refresh over existing rows does
  /// not set this — the rows stay put and the pull indicator carries the news.
  final bool loading;

  final String? error;
  final VoidCallback onRetry;

  /// How many rows fit before the user has to scroll. Fixed by the design;
  /// the row height is derived from it rather than the other way round, so
  /// the count holds on every screen size.
  static const int visibleRows = 6;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(scaled(context, 38)),
        boxShadow: kTrayLift,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          AppGlassSurface(
            style: glassAtRadius(kActivityTrayGlass, scaled(context, 38)),
            cornerRadius: scaled(context, 38),
            child: const SizedBox.expand(),
          ),
          Padding(
            padding: EdgeInsets.all(scaled(context, 12)),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double gap = scaled(context, 9);
                // Six rows and five gaps fill the tray exactly, so the sixth row
                // ends flush with the bottom rather than half-cut — a clipped
                // row reads as a rendering fault, not as an invitation to
                // scroll.
                //
                // Floored, because the tray is whatever the greeting and the
                // stat pills leave behind: squeeze it hard enough — a short
                // screen, a large system font — and the arithmetic goes
                // negative, which is a layout assertion rather than a small
                // row. Below the floor, fewer than six fit and the list
                // scrolls sooner.
                final double rowHeight = math.max(
                  scaled(context, 44),
                  (constraints.maxHeight - gap * (visibleRows - 1)) /
                      visibleRows,
                );
                final double rowRadius = (rowHeight / 2).clamp(
                  0.0,
                  scaled(context, 26),
                );

                if (loading) {
                  return const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          kGlassInkMuted,
                        ),
                      ),
                    ),
                  );
                }
                if (error != null || activities.isEmpty) {
                  // Scrollable even with nothing in it, so the pull-to-refresh
                  // above still has something to listen to — an empty tray is
                  // exactly when someone reaches for it.
                  return _Pullable(
                    height: constraints.maxHeight,
                    child: error != null
                        ? _TrayMessage(
                            text: error!,
                            action: ('Yenidən cəhd edin', onRetry),
                          )
                        : const _TrayMessage(
                            text: 'Hələ heç bir aktivlik yoxdur',
                          ),
                  );
                }

                // The outer tray and the moving row lenses are siblings. That
                // keeps glass scopes from nesting (which produced the old
                // rectangular texture artefact), while each row lens now
                // lives in the same list item as its text and travels with it.
                return ClipRect(
                  clipBehavior: Clip.hardEdge,
                  child: ScrollConfiguration(
                    // Android's stretch overscroll isolates the list's
                    // content into its own layer, and a lens that can no
                    // longer see the real backdrop paints black at both
                    // scroll edges. Rows are lenses, so the stretch goes.
                    behavior: const MaterialScrollBehavior().copyWith(
                      overscroll: false,
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      clipBehavior: Clip.hardEdge,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: activities.length,
                      itemExtent: rowHeight + gap,
                      itemBuilder: (BuildContext context, int index) {
                        return RepaintBoundary(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: gap),
                            child: _ActivityRow(
                              activity: activities[index],
                              height: rowHeight,
                              radius: rowRadius,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.activity,
    required this.height,
    required this.radius,
  });

  final Activity activity;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: AppGlassSurface(
        // `liquid_glass_easy` rather than the renderer the tray under it
        // uses — see [kActivityRowGlass]. The two are siblings in the Stack
        // above, so the row is painted after the tray and its backdrop
        // already contains it; nothing here has to nest.
        backend: AppGlassBackend.easy,
        style: glassAtRadius(kActivityRowGlass, radius),
        cornerRadius: radius,
        child: Padding(
          // Tighter than the stat rows': every point of inset here comes
          // straight off the end of the task title.
          padding: EdgeInsets.symmetric(horizontal: scaled(context, 16)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                activity.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: kGlassInk,
                  fontFamily: 'Poppins',
                  // Medium, not regular: it is the only thing separating this
                  // line from the name under it, now that both are Poppins.
                  fontWeight: FontWeight.w500,
                  // A notch below what CalSans took here. Poppins sets wider
                  // at the same size, and a typical task line — a quoted
                  // company name plus a status phrase — ran off the end.
                  fontSize: responsive(
                    context,
                    factor: 0.037,
                    min: 13,
                    max: 16,
                  ),
                  height: 1.15,
                  letterSpacing: -0.2,
                ),
              ),
              if (activity.subtitle != null) ...<Widget>[
                SizedBox(height: scaled(context, 3)),
                Text(
                  activity.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    color: kGlassInkMuted,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w400,
                    fontSize: responsive(
                      context,
                      factor: 0.034,
                      min: 12,
                      max: 14.5,
                    ),
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Makes a non-scrolling tray state answer a pull anyway.
class _Pullable extends StatelessWidget {
  const _Pullable({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(overscroll: false),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(height: height, child: child),
      ),
    );
  }
}

/// Whatever the tray has to say when it has no rows to show.
class _TrayMessage extends StatelessWidget {
  const _TrayMessage({required this.text, this.action});

  final String text;

  /// Label and callback for an optional button under the message.
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: scaled(context, 24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              text,
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: kGlassInkMuted,
                fontFamily: 'Poppins',
                fontSize: scaled(context, 14),
                height: 1.35,
              ),
            ),
            if (action != null) ...<Widget>[
              SizedBox(height: scaled(context, 14)),
              TextButton(
                onPressed: action!.$2,
                style: TextButton.styleFrom(
                  foregroundColor: kGlassInk,
                  textStyle: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: scaled(context, 14),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(action!.$1),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
