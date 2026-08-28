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
  });

  final TaskAction action;
  final double height;
  final double fontSize;

  /// Horizontal padding either side of the label.
  final double padding;

  final VoidCallback onTap;

  /// True while this card's verb is in flight — the label dims and taps stop
  /// landing, so a double tap cannot fire the same verb twice.
  final bool busy;

  @override
  State<TaskActionButton> createState() => _TaskActionButtonState();
}

class _TaskActionButtonState extends State<TaskActionButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final double radius = widget.height / 2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.busy ? null : (_) => setState(() => _down = true),
      onTapCancel: widget.busy ? null : () => setState(() => _down = false),
      onTapUp: widget.busy
          ? null
          : (_) {
              setState(() => _down = false);
              widget.onTap();
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
