import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../shared/motion/glass_touch_surface.dart';
import '../../../home/presentation/widgets/home_glass.dart';
import '../attendance_metrics.dart';
import 'attendance_card.dart';

/// The round glass button beside the greeting: the person glyph, on the
/// same glass as the stat rows under it. Opens the profile card.
class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key, required this.onOpen});

  /// Called with the button's rect in global coordinates — where the card
  /// will grow out of.
  final ValueChanged<Rect> onOpen;

  @override
  Widget build(BuildContext context) {
    final AttendanceMetrics m = AttendanceMetrics.of(context);
    final double d = m.profileDiameter;
    return Semantics(
      button: true,
      label: 'Profil',
      child: SizedBox.square(
        dimension: d,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: kGlassLift,
          ),
          // Its own layer: `GlassTouchSurface` draws into one, as the stat
          // rows do under theirs.
          child: AppGlassLayer(
            style: kStatPillGlass,
            child: Builder(
              builder: (BuildContext context) => GlassTouchSurface(
                style: kStatPillGlass,
                cornerRadius: d / 2,
                flex: const AppGlassFlex.statPill(),
                onTap: () {
                  final RenderBox box =
                      context.findRenderObject()! as RenderBox;
                  onOpen(box.localToGlobal(Offset.zero) & box.size);
                },
                child: Center(
                  child: SvgPicture.asset(
                    kAccountIcon,
                    width: m.profileIcon,
                    height: m.profileIcon,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
