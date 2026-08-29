import 'package:flutter/material.dart';

import 'task_glass.dart';

/// What a tool button hands back when it is pressed: its own rect in global
/// coordinates, and its corner.
///
/// The filter panel grows out of that rect, so the button has to say where it
/// is rather than merely that it was tapped — the same handover the start
/// button makes to the login card.
typedef TaskToolTap = void Function(Rect rect, double radius);

/// The two round glass buttons under the scope bar: filter, and new task.
///
/// The only real lenses on this screen besides the scope marker — the cards
/// are a flat fill over a background blur, by design — so they are the one
/// place the eye is meant to catch light. Both glyphs are painted rather than
/// set from an icon font: at 44pt a thin geometric funnel and a thin cross are
/// what the design draws, and Material's own are heavier and rounder.
class TaskToolButtons extends StatelessWidget {
  const TaskToolButtons({
    super.key,
    required this.size,
    required this.gap,
    required this.onFilter,
    required this.onCreate,
    this.filterCount = 0,
    this.filterHidden = false,
  });

  final double size;
  final double gap;
  final TaskToolTap onFilter;
  final VoidCallback onCreate;

  /// How many columns the filter is currently narrowing the list by. Drawn as
  /// a badge on the funnel, so a filtered list never looks like an empty one.
  final int filterCount;

  /// True while the filter panel is open.
  ///
  /// The panel *is* this button's glass once it opens, so the button steps
  /// out of the way rather than sitting under it and doubling both the lens
  /// and the glyph. Its space is kept, so nothing below moves.
  final bool filterHidden;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Visibility(
          visible: !filterHidden,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: _ToolButton(
            size: size,
            onTap: onFilter,
            semanticLabel: 'Filtr',
            painter: FunnelPainter(size),
            badge: filterCount,
          ),
        ),
        SizedBox(width: gap),
        _ToolButton(
          size: size,
          onTap: (Rect _, double _) => onCreate(),
          semanticLabel: 'Yeni tapşırıq',
          painter: _PlusPainter(size),
        ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.size,
    required this.onTap,
    required this.semanticLabel,
    required this.painter,
    this.badge = 0,
  });

  final double size;
  final TaskToolTap onTap;
  final String semanticLabel;
  final CustomPainter painter;
  final int badge;

  @override
  Widget build(BuildContext context) {
    // A squircle rather than a circle: at this size a true circle reads as a
    // bubble floating over the layout, while the softened square sits with the
    // scope bar above it.
    final double radius = size * 0.42;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // The rect is read from this element's own render object at the moment
        // of the tap rather than measured up front, so a button that has moved
        // — a rotation, a different scope bar height — still hands over where
        // it actually is.
        onTap: () {
          final RenderObject? box = context.findRenderObject();
          if (box is! RenderBox || !box.hasSize) return;
          onTap(box.localToGlobal(Offset.zero) & box.size, radius);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                boxShadow: kGlassLift,
              ),
              child: SizedBox.square(
                dimension: size,
                child: AppGlassSurface(
                  // Pinned to `liquid_glass_easy` for its optical border, the
                  // same as both travelling markers — see [kTaskToolGlass].
                  backend: AppGlassBackend.easy,
                  style: glassAtRadius(kTaskToolGlass, radius),
                  cornerRadius: radius,
                  flex: const AppGlassFlex.statPill(),
                  child: CustomPaint(painter: painter, size: Size.square(size)),
                ),
              ),
            ),
            if (badge > 0)
              Positioned(
                right: -size * 0.06,
                top: -size * 0.06,
                child: _CountDot(count: badge, size: size * 0.38),
              ),
          ],
        ),
      ),
    );
  }
}

/// The badge on the funnel. Sits proud of the glass rather than inside it: a
/// lens refracts what is behind it, and a number drawn on one is unreadable.
class _CountDot extends StatelessWidget {
  const _CountDot({required this.count, required this.size});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: size),
      height: size,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: size * 0.22),
      decoration: ShapeDecoration(
        color: kTaskFilterBadge,
        shape: const StadiumBorder(
          side: BorderSide(color: Color(0xF2FFFFFF), width: 1.5),
        ),
        shadows: kGlassLift,
      ),
      child: Text(
        '$count',
        maxLines: 1,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w600,
          fontSize: size * 0.6,
          height: 1,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// The filter glyph: a funnel drawn as a stroked outline.
///
/// Public because the filter panel wears it too — the glass that grows out of
/// this button carries the button's own glyph for the first few frames, and
/// the two have to be the same drawing rather than two of them.
class FunnelPainter extends CustomPainter {
  const FunnelPainter(this.box);

  /// The button's side, so the glyph scales with it rather than being pinned
  /// to one phone's numbers.
  final double box;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = box * 0.42;
    final Offset centre = Offset(size.width / 2, size.height / 2);
    final double left = centre.dx - s / 2;
    final double right = centre.dx + s / 2;
    final double top = centre.dy - s * 0.52;
    final double neck = centre.dy + s * 0.02;
    final double bottom = centre.dy + s * 0.55;
    final double stem = s * 0.16;

    final Path path = Path()
      ..moveTo(left, top)
      ..lineTo(right, top)
      ..lineTo(centre.dx + stem, neck)
      ..lineTo(centre.dx + stem, bottom)
      ..lineTo(centre.dx - stem, bottom - s * 0.16)
      ..lineTo(centre.dx - stem, neck)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = box * 0.048
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = kGlassInk,
    );
  }

  @override
  bool shouldRepaint(covariant FunnelPainter oldDelegate) =>
      oldDelegate.box != box;
}

/// The new-task glyph.
class _PlusPainter extends CustomPainter {
  const _PlusPainter(this.box);

  final double box;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = Offset(size.width / 2, size.height / 2);
    final double arm = box * 0.22;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = box * 0.058
      ..strokeCap = StrokeCap.round
      ..color = kGlassInk;

    canvas.drawLine(
      centre - Offset(arm, 0),
      centre + Offset(arm, 0),
      paint,
    );
    canvas.drawLine(
      centre - Offset(0, arm),
      centre + Offset(0, arm),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PlusPainter oldDelegate) =>
      oldDelegate.box != box;
}
