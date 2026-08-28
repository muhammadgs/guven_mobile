import 'package:flutter/material.dart';

import 'task_glass.dart';

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
  });

  final double size;
  final double gap;
  final VoidCallback onFilter;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _ToolButton(
          size: size,
          onTap: onFilter,
          semanticLabel: 'Filtr',
          painter: _FunnelPainter(size),
        ),
        SizedBox(width: gap),
        _ToolButton(
          size: size,
          onTap: onCreate,
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
  });

  final double size;
  final VoidCallback onTap;
  final String semanticLabel;
  final CustomPainter painter;

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
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: kGlassLift,
          ),
          child: SizedBox.square(
            dimension: size,
            child: AppGlassSurface(
              // Pinned to `liquid_glass_easy` for its optical border, the same
              // as both travelling markers — see [kTaskToolGlass].
              backend: AppGlassBackend.easy,
              style: glassAtRadius(kTaskToolGlass, radius),
              cornerRadius: radius,
              flex: const AppGlassFlex.statPill(),
              child: CustomPaint(painter: painter, size: Size.square(size)),
            ),
          ),
        ),
      ),
    );
  }
}

/// The filter glyph: a funnel drawn as a stroked outline.
class _FunnelPainter extends CustomPainter {
  const _FunnelPainter(this.box);

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
  bool shouldRepaint(covariant _FunnelPainter oldDelegate) =>
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
