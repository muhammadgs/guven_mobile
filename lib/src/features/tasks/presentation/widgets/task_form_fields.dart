/// The rows both task sheets are built out of.
///
/// `Yeni tapşırıq` and `Redaktə` are the same form asked twice — the same
/// heading-over-a-lens row, the same multiline box, the same switch, the same
/// pair of gradient buttons at the foot. They live here rather than in either
/// sheet so that a change to the way a field looks lands on both, which is the
/// only way the two can stay recognisably one thing.
///
/// Nothing here decides where anything sits on screen. Every size comes from
/// the [NewTaskMetrics] handed in, so both sheets land in the same place on
/// every phone (`layout-rules-are-binding`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../new_task_metrics.dart';
import 'new_task_box.dart';
import 'task_glass.dart';

/// What a field row hands back when it is tapped: its own rect in global
/// coordinates, so the panel that opens can grow out of exactly where it is —
/// including when the form has been scrolled and it is no longer where it was
/// built.
typedef FieldTap = void Function(Rect rect);

/// An icon and a heading — the line above every box on a sheet.
class TaskFormLabel extends StatelessWidget {
  const TaskFormLabel({
    super.key,
    required this.metrics,
    required this.icon,
    required this.text,
  });

  final NewTaskMetrics metrics;
  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SvgPicture.asset(
          icon,
          width: metrics.labelSize * 1.35,
          height: metrics.labelSize * 1.35,
          colorFilter: const ColorFilter.mode(kGlassInk, BlendMode.srcIn),
        ),
        SizedBox(width: 8 * metrics.scale),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: metrics.labelSize,
              height: 1.15,
              color: kGlassInk,
            ),
          ),
        ),
      ],
    );
  }
}

/// A heading and the box under it — one answerable field.
class TaskFormField extends StatelessWidget {
  const TaskFormField({
    super.key,
    required this.metrics,
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
    required this.active,
    required this.onTap,
    this.busy = false,
  });

  final NewTaskMetrics metrics;
  final String icon;
  final String label;

  /// The answer, or null while there is none — which is what decides both the
  /// ink and the weight the row is set in.
  final String? value;
  final String hint;

  /// True while the list behind this field is still being fetched — the box
  /// stays tappable, and the panel shows the spinner.
  final bool busy;

  /// True while this field's own panel is up, so its box can step aside for
  /// it.
  final bool active;

  final FieldTap onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TaskFormLabel(metrics: metrics, icon: icon, text: label),
        SizedBox(height: metrics.fieldGap),
        TaskFormBox(
          metrics: metrics,
          active: active,
          onTap: onTap,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  value ?? hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: value == null
                        ? FontWeight.w400
                        : FontWeight.w500,
                    fontSize: metrics.valueSize,
                    height: 1.2,
                    color: value == null ? kNewTaskHintInk : kNewTaskValueInk,
                  ),
                ),
              ),
              if (busy)
                SizedBox.square(
                  dimension: metrics.valueSize,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kNewTaskHintInk,
                  ),
                )
              else
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: metrics.valueSize * 1.5,
                  color: kNewTaskHintInk,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The box itself.
///
/// It reads its own render object at the moment of the tap rather than being
/// measured up front, so a field the form has been scrolled past still says
/// where it actually is — and while its panel is open it hides, because that
/// panel is this box's glass.
class TaskFormBox extends StatelessWidget {
  const TaskFormBox({
    super.key,
    required this.metrics,
    required this.active,
    required this.onTap,
    required this.child,
  });

  final NewTaskMetrics metrics;
  final bool active;
  final FieldTap onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final RenderObject? box = context.findRenderObject();
        if (box is! RenderBox || !box.hasSize) return;
        onTap(box.localToGlobal(Offset.zero) & box.size);
      },
      child: NewTaskBox(
        radius: metrics.fieldHeight / 2,
        hidden: active,
        child: Container(
          height: metrics.fieldHeight,
          padding: EdgeInsets.symmetric(horizontal: 16 * metrics.scale),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

/// One line with a switch on the end — `Seçilmiş şirkətə göstər`.
class TaskFormToggle extends StatelessWidget {
  const TaskFormToggle({
    super.key,
    required this.metrics,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final NewTaskMetrics metrics;
  final String icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return NewTaskBox(
      radius: metrics.fieldHeight / 2,
      child: Container(
        height: metrics.fieldHeight,
        padding: EdgeInsets.fromLTRB(
          14 * metrics.scale,
          0,
          6 * metrics.scale,
          0,
        ),
        child: Row(
          children: <Widget>[
            SvgPicture.asset(
              icon,
              width: metrics.labelSize * 1.3,
              height: metrics.labelSize * 1.3,
              colorFilter: const ColorFilter.mode(kGlassInk, BlendMode.srcIn),
            ),
            SizedBox(width: 8 * metrics.scale),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: metrics.labelSize * 0.94,
                  height: 1.15,
                  color: kGlassInk,
                ),
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF2BD07E),
              inactiveTrackColor: const Color(0x2E101826),
            ),
          ],
        ),
      ),
    );
  }
}

/// A box that is typed into rather than chosen from — the description and the
/// note.
class TaskFormTextBox extends StatelessWidget {
  const TaskFormTextBox({
    super.key,
    required this.metrics,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.minLines = 3,
  });

  final NewTaskMetrics metrics;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    final double radius = 24 * metrics.scale;

    return NewTaskBox(
      radius: radius,
      child: Container(
        constraints: BoxConstraints(minHeight: 110 * metrics.scale),
        padding: EdgeInsets.symmetric(
          horizontal: 16 * metrics.scale,
          vertical: 12 * metrics.scale,
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          maxLines: null,
          minLines: minLines,
          textInputAction: TextInputAction.newline,
          keyboardType: TextInputType.multiline,
          cursorColor: kGlassInk,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: metrics.valueSize,
            height: 1.35,
            color: kNewTaskValueInk,
          ),
          decoration: InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
            hintText: hint,
            hintStyle: TextStyle(
              fontFamily: 'Poppins',
              fontSize: metrics.valueSize,
              height: 1.35,
              color: kNewTaskHintInk,
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the two pills at the foot of a sheet.
class TaskFormButton extends StatelessWidget {
  const TaskFormButton({
    super.key,
    required this.metrics,
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final NewTaskMetrics metrics;
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double height = 46 * metrics.scale;

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: 14 * metrics.scale),
          decoration: ShapeDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: gradient,
            ),
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: height * 0.46,
                height: height * 0.46,
                alignment: Alignment.center,
                decoration: const ShapeDecoration(
                  color: Color(0x33FFFFFF),
                  shape: CircleBorder(),
                ),
                child: Icon(icon, size: height * 0.32, color: kTaskButtonInk),
              ),
              SizedBox(width: 8 * metrics.scale),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    fontSize: metrics.valueSize,
                    height: 1.1,
                    color: kTaskButtonInk,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The title and the way back, at the head of a sheet.
class TaskFormHeader extends StatelessWidget {
  const TaskFormHeader({
    super.key,
    required this.metrics,
    required this.title,
    required this.onBack,
  });

  final NewTaskMetrics metrics;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final double box = 34 * metrics.scale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            maxLines: 1,
            style: TextStyle(
              color: kGlassInk,
              // CalSans, this app's display face: the sheet's title is a page
              // title like the screen's own.
              fontFamily: 'CalSans',
              fontSize: metrics.sheetTitleSize,
              height: 1.05,
              letterSpacing: -0.8,
            ),
          ),
        ),
        SizedBox(height: 10 * metrics.scale),
        Semantics(
          button: true,
          label: 'Geri',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBack,
            child: NewTaskBox(
              radius: box / 2,
              child: SizedBox.square(
                dimension: box,
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: box * 0.68,
                  color: kNewTaskValueInk,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
