import 'package:flutter/material.dart';

import '../../../../shared/layout.dart';
import '../../../home/presentation/widgets/home_glass.dart';

/// Stands in for a tab that has not been built yet.
///
/// Only the home screen is real so far, but the nav bar has five cells and the
/// selection has to be allowed to land on any of them — a tab that vanished
/// under the finger would make the bar itself feel broken. So each of the
/// others says plainly that it is not ready, on the same glass as everything
/// else.
class ComingSoonTab extends StatelessWidget {
  const ComingSoonTab({
    super.key,
    required this.title,
    required this.bottomReserve,
  });

  final String title;
  final double bottomReserve;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final double radius = scaled(context, 34);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        scaled(context, 24),
        safe.top + scaled(context, 10),
        scaled(context, 24),
        bottomReserve,
      ),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: kTrayLift,
          ),
          child: AppGlassSurface(
            style: glassAtRadius(kActivityTrayGlass, radius),
            cornerRadius: radius,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: scaled(context, 32),
                vertical: scaled(context, 30),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: kGlassInk,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      fontSize: responsive(
                        context,
                        factor: 0.066,
                        min: 24,
                        max: 30,
                      ),
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: scaled(context, 10)),
                  Text(
                    'Bu bölmə hazırlanır.',
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: kGlassInkMuted,
                      fontFamily: 'Poppins',
                      fontSize: scaled(context, 14),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
