import 'package:flutter/material.dart';

import 'task_glass.dart';

/// Whether the sheet has finished flying, published to everything inside it.
///
/// The boxes on the form are lenses, and a lens cannot be drawn while its
/// contents are being faded in: the fade is an `Opacity`, an `Opacity` opens a
/// `saveLayer`, and a lens under one samples that empty layer and comes out
/// black ([backdrop-filter-black-flash]). So the form asks here whether it is
/// safe to be glass yet, and wears [kNewTaskFieldFill] until it is.
///
/// Absent, the answer is yes — a form built outside the morph (a widget test)
/// is at rest by definition.
class NewTaskGlass extends InheritedWidget {
  const NewTaskGlass({super.key, required this.settled, required super.child});

  final bool settled;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NewTaskGlass>()?.settled ??
      true;

  @override
  bool updateShouldNotify(NewTaskGlass oldWidget) =>
      oldWidget.settled != settled;
}

/// One box on the `Yeni tapşırıq` sheet: a field, the description, the
/// recorder, a round button.
///
/// [child] carries its own height and padding — the lens takes the size of
/// what is inside it.
class NewTaskBox extends StatelessWidget {
  const NewTaskBox({
    super.key,
    required this.radius,
    required this.child,
    this.hidden = false,
  });

  final double radius;
  final Widget child;

  /// True while this box's own panel is open.
  ///
  /// The panel *is* this box's glass once it opens, so the box steps out of
  /// the way rather than sitting under it and doubling the lens — the same
  /// handover the funnel button makes to the filter. Its space is kept, so
  /// nothing on the form moves.
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final Widget surface = NewTaskGlass.of(context)
        ? AppGlassSurface(
            style: glassAtRadius(kNewTaskFieldGlass, radius),
            cornerRadius: radius,
            child: child,
          )
        : DecoratedBox(
            decoration: ShapeDecoration(
              color: kNewTaskFieldFill,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
            child: child,
          );

    if (!hidden) return surface;
    return Visibility(
      visible: false,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: surface,
    );
  }
}
