import 'package:flutter/material.dart';

import '../../domain/task_status.dart';
import 'task_glass.dart';

/// One of the design's gradient pills.
///
/// The gradients are the Figma stops exactly, on [TaskAction.gradient], and
/// they run left to right across the button's own width — not the card's — so
/// `Təsdiq et` and `İmtina et` each carry a full sweep rather than two halves
/// of one.
///
/// Everything about its size is passed in, because the buttons grow as a card
/// opens: the same widget is a 32pt pill in a shut card and a 44pt one in an
/// open card, and the growth is a continuous lerp rather than two designs.
class TaskActionButton extends StatefulWidget {
  const TaskActionButton({
    super.key,
    required this.action,
    required this.height,
    required this.fontSize,
    required this.padding,
    required this.onTap,
    this.busy = false,
    this.hidden = false,
  });

  final TaskAction action;
  final double height;
  final double fontSize;

  /// Horizontal padding either side of the label.
  final double padding;

  /// Fired with this button's own rect in global coordinates, read from its
  /// render object at the moment of the tap.
  ///
  /// `Redaktə` grows out of the button that was pressed, and the card it sits
  /// on is halfway down a scrolling list — so where the button *is* can only
  /// be answered when it is pressed, never when it was built.
  final void Function(Rect rect) onTap;

  /// True while this card's verb is in flight — the label dims and taps stop
  /// landing, so a double tap cannot fire the same verb twice.
  final bool busy;

  /// True while the sheet this button opened is up.
  ///
  /// That sheet *is* this button's surface for as long as it is on screen, so
  /// the button steps out from under it rather than sitting there behind the
  /// scrim — the same handover the `+` makes to `Yeni tapşırıq`. Its space is
  /// kept, so the card does not move.
  final bool hidden;

  @override
  State<TaskActionButton> createState() => _TaskActionButtonState();
}

class _TaskActionButtonState extends State<TaskActionButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final double radius = widget.height / 2;

    final Widget button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.busy ? null : (_) => setState(() => _down = true),
      onTapCancel: widget.busy ? null : () => setState(() => _down = false),
      onTapUp: widget.busy
          ? null
          : (_) {
              setState(() => _down = false);
              final RenderObject? box = context.findRenderObject();
              if (box is! RenderBox || !box.hasSize) return;
              widget.onTap(box.localToGlobal(Offset.zero) & box.size);
            },
      child: AnimatedScale(
        scale: _down ? 0.955 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: widget.busy ? 0.55 : 1,
          duration: const Duration(milliseconds: 160),
          child: Container(
            height: widget.height,
            padding: EdgeInsets.symmetric(horizontal: widget.padding),
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: widget.action.gradient,
              ),
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
            child: Text(
              widget.action.label,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                fontSize: widget.fontSize,
                height: 1.1,
                color: kTaskButtonInk,
              ),
            ),
          ),
        ),
      ),
    );

    if (!widget.hidden) return button;
    return Visibility(
      visible: false,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: button,
    );
  }
}

/// What a card shows instead of buttons: the task's state, for a task nobody
/// here is expected to act on.
class TaskStatusChip extends StatelessWidget {
  const TaskStatusChip({
    super.key,
    required this.status,
    required this.height,
    required this.fontSize,
    required this.padding,
  });

  final TaskStatus status;
  final double height;
  final double fontSize;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: padding),
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: status.chipColor,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
      child: Text(
        status.label,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w500,
          fontSize: fontSize,
          height: 1.1,
          color: kTaskButtonInk,
        ),
      ),
    );
  }
}
