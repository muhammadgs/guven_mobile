import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// The nine things a task card places, in the order they must be handed to
/// [TaskCardLayout].
enum TaskCardSlot {
  /// Date and time, as one line.
  stamp,

  /// The company name.
  title,

  /// The work type.
  subtitle,

  /// `Kim tərəfindən` — the person who handed the task over.
  fromName,

  /// `İcra edən` — the person carrying it out.
  toName,

  description,

  /// The gradient buttons, or the status chip when there is nothing to press.
  actions,

  /// Files and the deadline. Only on an opened card; it is laid out either
  /// way, and parked below the fold while the card is shut.
  extras,

  /// The open/close chevron at the bottom edge.
  chevron,
}

/// Distances the card is built from, already scaled to the device.
@immutable
class TaskCardMetrics {
  const TaskCardMetrics({
    required this.headerGap,
    required this.nameGap,
    required this.actionsGap,
    required this.columnGap,
    required this.leftFraction,
    required this.stackGap,
    required this.dotRadius,
    required this.dotLane,
    required this.connectorSpan,
    required this.chevronGap,
  });

  /// Header to body.
  final double headerGap;

  /// Between the two names when they are stacked.
  final double nameGap;

  /// Names to buttons, in the shut card's left column.
  final double actionsGap;

  /// Between the left column and the description, in the shut card.
  final double columnGap;

  /// How much of the width the left column takes when the card is shut.
  final double leftFraction;

  /// The vertical rhythm of the opened card.
  final double stackGap;

  final double dotRadius;

  /// Room kept to the left of the stacked names for their bullets.
  final double dotLane;

  /// Room the arrow needs between the two names when they sit side by side.
  final double connectorSpan;

  final double chevronGap;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TaskCardMetrics &&
        other.headerGap == headerGap &&
        other.nameGap == nameGap &&
        other.actionsGap == actionsGap &&
        other.columnGap == columnGap &&
        other.leftFraction == leftFraction &&
        other.stackGap == stackGap &&
        other.dotRadius == dotRadius &&
        other.dotLane == dotLane &&
        other.connectorSpan == connectorSpan &&
        other.chevronGap == chevronGap;
  }

  @override
  int get hashCode => Object.hash(
    headerGap,
    nameGap,
    actionsGap,
    columnGap,
    leftFraction,
    stackGap,
    dotRadius,
    dotLane,
    connectorSpan,
    chevronGap,
  );
}

/// Lays a task card out twice and shows the blend.
///
/// The shut card is two columns — names and buttons on the left, description
/// on the right, timestamp tucked up beside the company name. The open card is
/// one centred column — timestamp above the title, the two people side by side
/// with an arrow between them, then the description across the full width, the
/// buttons under it, and the files and deadline under those. There is no
/// arrangement of one that is a rearrangement of the other, so nothing here
/// tries to animate a `Column` into a `Row`.
///
/// Instead every child is measured once, at the width it should have *at this
/// moment* of the animation, and then both layouts are computed from those
/// measurements and lerped. At 0 and at 1 the result is exactly one of the two
/// designs; in between, every element travels along a straight line between
/// where it was and where it is going, and the card's height travels with
/// them. The connector between the two names is painted from the same pair of
/// layouts, which is what lets the bracket under the first bullet straighten
/// into a horizontal arrow as the names move apart.
class TaskCardLayout extends MultiChildRenderObjectWidget {
  TaskCardLayout({
    super.key,
    required this.expansion,
    required this.metrics,
    required this.connectorColor,
    required Map<TaskCardSlot, Widget> slots,
  }) : super(
         children: <Widget>[
           for (final TaskCardSlot slot in TaskCardSlot.values)
             slots[slot] ?? const SizedBox.shrink(),
         ],
       );

  /// 0 shut, 1 open.
  final double expansion;
  final TaskCardMetrics metrics;

  /// The ink the bullets and the arrow are drawn in.
  final Color connectorColor;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderTaskCardLayout(
      expansion: expansion,
      metrics: metrics,
      connectorColor: connectorColor,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderTaskCardLayout renderObject,
  ) {
    renderObject
      ..expansion = expansion
      ..metrics = metrics
      ..connectorColor = connectorColor;
  }
}

class TaskCardParentData extends ContainerBoxParentData<RenderBox> {}

/// One child's place in one of the two layouts.
class _Placement {
  _Placement(this.offset, this.size);

  Offset offset;
  final Size size;

  Rect get rect => offset & size;
}

class RenderTaskCardLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, TaskCardParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, TaskCardParentData> {
  /// Assigned in the body rather than in an initialiser list: the fields
  /// behind these three are private, and a named initialising formal may not
  /// carry a private name.
  RenderTaskCardLayout({
    required double expansion,
    required TaskCardMetrics metrics,
    required Color connectorColor,
  }) {
    _expansion = expansion;
    _metrics = metrics;
    _connectorColor = connectorColor;
  }

  late double _expansion;
  double get expansion => _expansion;
  set expansion(double value) {
    if (_expansion == value) return;
    _expansion = value;
    markNeedsLayout();
  }

  late TaskCardMetrics _metrics;
  TaskCardMetrics get metrics => _metrics;
  set metrics(TaskCardMetrics value) {
    if (_metrics == value) return;
    _metrics = value;
    markNeedsLayout();
  }

  late Color _connectorColor;
  Color get connectorColor => _connectorColor;
  set connectorColor(Color value) {
    if (_connectorColor == value) return;
    _connectorColor = value;
    markNeedsPaint();
  }

  /// Where the two names sit in each layout, kept from the last pass so the
  /// connector can be drawn between them.
  Rect _fromShut = Rect.zero;
  Rect _toShut = Rect.zero;
  Rect _fromOpen = Rect.zero;
  Rect _toOpen = Rect.zero;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! TaskCardParentData) {
      child.parentData = TaskCardParentData();
    }
  }

  RenderBox _slot(TaskCardSlot slot) {
    RenderBox? child = firstChild;
    for (int i = 0; i < slot.index; i++) {
      child = (child!.parentData! as TaskCardParentData).nextSibling;
    }
    return child!;
  }

  @override
  void performLayout() {
    size = constraints.constrain(_layoutPass(constraints, dry: false));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(_layoutPass(constraints, dry: true));

  /// Measures every child, builds both layouts, and — when this is the real
  /// pass — writes the blended offsets into the children's parent data.
  Size _layoutPass(BoxConstraints constraints, {required bool dry}) {
    assert(childCount == TaskCardSlot.values.length);
    final double width = constraints.hasBoundedWidth ? constraints.maxWidth : 0;
    final double t = _expansion.clamp(0.0, 1.0);
    final TaskCardMetrics m = _metrics;

    Size measure(TaskCardSlot slot, BoxConstraints childConstraints) {
      final RenderBox child = _slot(slot);
      if (dry) return child.getDryLayout(childConstraints);
      child.layout(childConstraints, parentUsesSize: true);
      return child.size;
    }

    // ------------------------------------------------------------- measuring
    //
    // Each child is asked for the width it should have *now*, so its height is
    // the one the blend actually needs. A description halfway open is a little
    // over half as wide as it will be, and that is exactly the height that
    // goes into both of the layouts below.

    final double leftWidth = width * m.leftFraction;
    final double rightWidth = math.max(0, width - leftWidth - m.columnGap);

    final Size stamp = measure(
      TaskCardSlot.stamp,
      BoxConstraints(maxWidth: width),
    );

    final double headlineShut = math.max(width - stamp.width - m.columnGap, 40);
    final double headlineWidth = lerpDouble(headlineShut, width, t)!;
    final Size title = measure(
      TaskCardSlot.title,
      BoxConstraints(maxWidth: headlineWidth),
    );
    final Size subtitle = measure(
      TaskCardSlot.subtitle,
      BoxConstraints(maxWidth: headlineWidth),
    );

    // Stacked, a name has the left column less the bullet lane. Side by side,
    // the two share one line: the first takes what it needs and the second is
    // given whatever is left, so a short name beside a long one is not held to
    // half a card it does not need.
    final double nameShut = math.max(leftWidth - m.dotLane, 40);
    final Size fromName = measure(
      TaskCardSlot.fromName,
      BoxConstraints(
        maxWidth: lerpDouble(
          nameShut,
          math.max(width - m.connectorSpan - 40, 40),
          t,
        )!,
      ),
    );
    final Size toName = measure(
      TaskCardSlot.toName,
      BoxConstraints(
        maxWidth: lerpDouble(
          nameShut,
          math.max(width - m.connectorSpan - fromName.width, 40),
          t,
        )!,
      ),
    );

    // The description is the one child given a tight width: it is a block of
    // text that must fill its column, and a `Text` left loose would size to
    // its longest line and stop sitting flush with the card's edge.
    final double descriptionWidth = lerpDouble(rightWidth, width, t)!;
    final Size description = measure(
      TaskCardSlot.description,
      BoxConstraints.tightFor(width: descriptionWidth),
    );

    final Size actions = measure(
      TaskCardSlot.actions,
      BoxConstraints(maxWidth: lerpDouble(leftWidth + m.columnGap, width, t)!),
    );
    final Size extras = measure(
      TaskCardSlot.extras,
      BoxConstraints.tightFor(width: width),
    );
    final Size chevron = measure(
      TaskCardSlot.chevron,
      BoxConstraints(maxWidth: width),
    );

    // ----------------------------------------------------------- the shut card

    final _Placement stampShut = _Placement(
      Offset(
        width - stamp.width,
        math.max(0, (title.height - stamp.height) / 2),
      ),
      stamp,
    );
    final _Placement titleShut = _Placement(Offset.zero, title);
    final _Placement subtitleShut = _Placement(
      Offset(0, title.height),
      subtitle,
    );

    final double bodyTop =
        subtitleShut.offset.dy + subtitle.height + m.headerGap;
    final _Placement fromShut = _Placement(
      Offset(m.dotLane, bodyTop),
      fromName,
    );
    final _Placement toShut = _Placement(
      Offset(m.dotLane, bodyTop + fromName.height + m.nameGap),
      toName,
    );
    final _Placement actionsShut = _Placement(
      Offset(0, toShut.offset.dy + toName.height + m.actionsGap),
      actions,
    );
    final _Placement descriptionShut = _Placement(
      Offset(width - descriptionWidth, bodyTop),
      description,
    );

    final double bodyBottomShut = math.max(
      actionsShut.rect.bottom,
      descriptionShut.rect.bottom,
    );
    // Parked below the fold, where the card's own clip hides it. The widget
    // fades it in as well, so nothing shows through on the way past.
    final _Placement extrasShut = _Placement(Offset(0, bodyBottomShut), extras);
    final _Placement chevronShut = _Placement(
      Offset((width - chevron.width) / 2, bodyBottomShut + m.chevronGap),
      chevron,
    );
    final double heightShut = chevronShut.rect.bottom;

    // ----------------------------------------------------------- the open card

    final _Placement stampOpen = _Placement(
      Offset((width - stamp.width) / 2, 0),
      stamp,
    );
    final _Placement titleOpen = _Placement(
      Offset((width - title.width) / 2, stamp.height + m.chevronGap),
      title,
    );
    final _Placement subtitleOpen = _Placement(
      Offset((width - subtitle.width) / 2, titleOpen.offset.dy + title.height),
      subtitle,
    );

    final double peopleTop =
        subtitleOpen.offset.dy + subtitle.height + m.stackGap;
    final double rowWidth = fromName.width + m.connectorSpan + toName.width;
    final double rowLeft = math.max(0, (width - rowWidth) / 2);
    final double rowHeight = math.max(fromName.height, toName.height);
    final _Placement fromOpen = _Placement(
      Offset(rowLeft, peopleTop + (rowHeight - fromName.height) / 2),
      fromName,
    );
    final _Placement toOpen = _Placement(
      Offset(
        rowLeft + fromName.width + m.connectorSpan,
        peopleTop + (rowHeight - toName.height) / 2,
      ),
      toName,
    );
    final _Placement descriptionOpen = _Placement(
      Offset(0, peopleTop + rowHeight + m.stackGap),
      description,
    );
    final _Placement actionsOpen = _Placement(
      Offset(
        (width - actions.width) / 2,
        descriptionOpen.rect.bottom + m.stackGap,
      ),
      actions,
    );
    final _Placement extrasOpen = _Placement(
      Offset(0, actionsOpen.rect.bottom + (extras.height > 0 ? m.stackGap : 0)),
      extras,
    );
    final _Placement chevronOpen = _Placement(
      Offset(
        (width - chevron.width) / 2,
        extrasOpen.rect.bottom + m.chevronGap,
      ),
      chevron,
    );
    final double heightOpen = chevronOpen.rect.bottom;

    if (!dry) {
      void place(TaskCardSlot slot, _Placement shut, _Placement open) {
        (_slot(slot).parentData! as TaskCardParentData).offset = Offset(
          lerpDouble(shut.offset.dx, open.offset.dx, t)!,
          lerpDouble(shut.offset.dy, open.offset.dy, t)!,
        );
      }

      place(TaskCardSlot.stamp, stampShut, stampOpen);
      place(TaskCardSlot.title, titleShut, titleOpen);
      place(TaskCardSlot.subtitle, subtitleShut, subtitleOpen);
      place(TaskCardSlot.fromName, fromShut, fromOpen);
      place(TaskCardSlot.toName, toShut, toOpen);
      place(TaskCardSlot.description, descriptionShut, descriptionOpen);
      place(TaskCardSlot.actions, actionsShut, actionsOpen);
      place(TaskCardSlot.extras, extrasShut, extrasOpen);
      place(TaskCardSlot.chevron, chevronShut, chevronOpen);

      _fromShut = fromShut.rect;
      _toShut = toShut.rect;
      _fromOpen = fromOpen.rect;
      _toOpen = toOpen.rect;
    }

    return Size(width, lerpDouble(heightShut, heightOpen, t)!);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _paintConnector(context.canvas, offset);
    defaultPaint(context, offset);
  }

  /// The bullets and the arrow between the two people.
  ///
  /// Shut, it is a bracket dropping out of the first bullet and curling into
  /// the second from the left. Open, it is a straight arrow from one name to
  /// the other. Both are the same cubic with different control points, so the
  /// one bends into the other rather than being swapped for it.
  void _paintConnector(Canvas canvas, Offset offset) {
    if (_fromShut == Rect.zero && _fromOpen == Rect.zero) return;

    final double t = _expansion.clamp(0.0, 1.0);
    final double r = _metrics.dotRadius;

    Offset lerpOffset(Offset a, Offset b) =>
        Offset(lerpDouble(a.dx, b.dx, t)!, lerpDouble(a.dy, b.dy, t)!);

    // Where the two bullets are: to the left of the stacked names, and hard
    // against the inner edge of each name once they sit side by side.
    final Offset first = lerpOffset(
      Offset(_fromShut.left - _metrics.dotLane / 2, _fromShut.center.dy),
      Offset(_fromOpen.right + r * 2.6, _fromOpen.center.dy),
    );
    final Offset second = lerpOffset(
      Offset(_toShut.left - _metrics.dotLane / 2, _toShut.center.dy),
      Offset(_toOpen.left - r * 2.6, _toOpen.center.dy),
    );

    final double span = second.dx - first.dx;
    final double drop = second.dy - first.dy;
    final double hook = _metrics.dotLane * 0.55;

    final Offset start = lerpOffset(
      Offset(first.dx, first.dy + r + 1.5),
      Offset(first.dx + r + 2.5, first.dy),
    );
    final Offset control1 = lerpOffset(
      Offset(first.dx - hook, first.dy + drop * 0.45),
      Offset(first.dx + span * 0.34, first.dy),
    );
    final Offset control2 = lerpOffset(
      Offset(second.dx - hook, second.dy - drop * 0.25),
      Offset(second.dx - span * 0.34, second.dy),
    );
    // The head lands on the second bullet from the left in both layouts, so
    // this one point does not need blending.
    final Offset end = Offset(second.dx - r - 2.5, second.dy);

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = _connectorColor;

    canvas.save();
    canvas.translate(offset.dx, offset.dy);

    canvas.drawPath(
      Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          control1.dx,
          control1.dy,
          control2.dx,
          control2.dy,
          end.dx,
          end.dy,
        ),
      stroke,
    );

    // The head points along the curve's own tangent, so it turns from
    // pointing down-right to pointing right as the card opens.
    final Offset tangent = end - control2;
    final double angle = math.atan2(tangent.dy, tangent.dx);
    const double barb = 4.6;
    for (final double sweep in <double>[2.6, -2.6]) {
      canvas.drawLine(
        end,
        end + Offset(math.cos(angle + sweep), math.sin(angle + sweep)) * barb,
        stroke,
      );
    }

    final Paint fill = Paint()..color = _connectorColor;
    canvas.drawCircle(first, r, fill);
    canvas.drawCircle(second, r, fill);
    canvas.restore();
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
