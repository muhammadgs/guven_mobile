import 'package:flutter/material.dart';

import '../glass/app_glass.dart';
import 'glass_shimmer.dart';

/// A glass surface that answers a finger the way Apple's does: it deforms
/// under the press and lights up *where* it was pressed.
///
/// Renderer deformation, touch glow and rim lighting share the same gesture.
///
/// Sibling to [GlassPressButton], which does the same for a fixed-size control
/// with a tap action. This one takes its size from layout and has no action of
/// its own, which is what the wide stat rows need.
class GlassTouchSurface extends StatefulWidget {
  const GlassTouchSurface({
    super.key,
    required this.style,
    required this.cornerRadius,
    required this.child,
    this.flex = const AppGlassFlex.pronounced(),
    this.glowColor = const Color(0x30FFFFFF),
    this.glowReach = 3.4,
    this.glowRadius = 5.62,
    this.onTap,
  });

  /// Colour of the touch light, at its brightest point.
  ///
  /// Additive, so on a pale surface white reads as the glass catching light
  /// rather than as a grey blob. Which is also why the alpha is low: `plus`
  /// clips once the sum passes white, and a clipped region is a flat patch
  /// with a hard edge — the "solid disc" look. Everything above roughly 0.2
  /// on this app's pale glass draws exactly that.
  final Color glowColor;

  /// Radius of the held light, as a **multiple** of the surface's shortest
  /// side.
  ///
  /// Above 1 on purpose. A stat pill is short and wide, so a circle larger
  /// than its height has its top and bottom clipped away by the pill itself,
  /// and what is left is a horizontal gradient with no arc anywhere in it.
  /// That is what makes the light read as a haze that happens to be round
  /// rather than as a circle drawn on the glass.
  final double glowReach;

  /// Radius of the rollback backend's package glow, as a fraction of the
  /// shortest side. Unused on the renderer, which draws its own light.
  final double glowRadius;

  /// The resting look. Its corner radius is replaced by [cornerRadius] — see
  /// [glassAtRadius].
  final AppGlassStyle style;

  final double cornerRadius;

  /// Rides on top of the glass, deforming with it.
  final Widget child;

  /// How far the renderer's [AppGlassSurface] gives under a pointer.
  final AppGlassFlex flex;

  /// Optional — the surface responds to touch either way.
  final VoidCallback? onTap;

  @override
  State<GlassTouchSurface> createState() => _GlassTouchSurfaceState();
}

class _GlassTouchSurfaceState extends State<GlassTouchSurface>
    with TickerProviderStateMixin {
  AnimationController? _legacyShimmer;

  /// Brings the light up under a finger that has just landed.
  AnimationController? _hold;

  /// Runs once on release. The light lets go of the finger, floods outwards
  /// across the whole surface and dies on the way — so a press ends with the
  /// pill lighting up as a whole, rather than with a spot switching off.
  AnimationController? _wash;

  /// Where the light comes from for the flash currently running.
  double _towards = 0;
  Offset _glowPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    if (kUseLegacyEasyGlass) {
      _legacyShimmer = AnimationController(
        vsync: this,
        duration: kGlassShimmerDuration,
      );
      return;
    }
    _hold = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 170),
    );
    // Long enough for the spread to be a movement the eye can follow across
    // the pill, rather than a fade that happens to get wider.
    _wash = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
  }

  @override
  void dispose() {
    _legacyShimmer?.dispose();
    _hold?.dispose();
    _wash?.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    // Renderer owns both the point glow and deformation. Its shared layer
    // settings cannot be animated per pill, so rebuilding them here would do
    // work without changing a pixel. Keep the old rim flash only for the
    // rollback backend, where every lens owns its style.
    if (!kUseLegacyEasyGlass) {
      setState(() => _glowPosition = event.localPosition);
      _wash!.value = 0;
      _hold!.forward(from: 0);
      return;
    }

    // `context.size` is this element's box, which is the lens's box — the
    // Listener wraps it directly, so `localPosition` is already in the same
    // space. Laid out by the time a pointer can land on it.
    final Size? size = context.size;
    if (size == null || size.isEmpty) return;
    _towards = lightAngleTowards(event.localPosition, size);
    _legacyShimmer!.forward(from: 0);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (kUseLegacyEasyGlass || _hold!.value == 0) return;
    // The light is pinned to the finger, not dragged after it: wherever the
    // finger goes, that is where the haze already is.
    setState(() => _glowPosition = event.localPosition);
  }

  void _onPointerEnd(PointerEvent event) {
    if (kUseLegacyEasyGlass) return;
    // [_hold] is deliberately left running. A tap released inside 170ms still
    // brightens on its way out instead of washing from half-lit, which is the
    // difference between a tap that answers and one that looks dropped.
    _wash!.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final AppGlassStyle resting = glassAtRadius(
      widget.style,
      widget.cornerRadius,
    );

    Widget buildSurface(
      AppGlassStyle style,
      Widget child, {
      required bool usePackageGlow,
    }) {
      return AppGlassSurface(
        style: style,
        cornerRadius: widget.cornerRadius,
        flex: widget.flex,
        glowColor: usePackageGlow ? widget.glowColor : null,
        glowRadius: widget.glowRadius,
        useOwnLayer: false,
        child: child,
      );
    }

    final Widget surface = kUseLegacyEasyGlass
        ? AnimatedBuilder(
            animation: _legacyShimmer!,
            child: widget.child,
            builder: (BuildContext context, Widget? child) {
              return buildSurface(
                shimmerAppGlassStyle(
                  resting,
                  _legacyShimmer!.value,
                  towards: _towards,
                ),
                child!,
                usePackageGlow: true,
              );
            },
          )
        : buildSurface(
            resting,
            Stack(
              fit: StackFit.passthrough,
              children: <Widget>[
                Positioned.fill(
                  child: IgnorePointer(
                    // The clip is half the effect: it is what cuts the top
                    // and bottom off a light wider than the pill is tall.
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(widget.cornerRadius),
                      child: AnimatedBuilder(
                        animation: Listenable.merge(<Listenable>[
                          _hold!,
                          _wash!,
                        ]),
                        builder: (BuildContext context, Widget? child) {
                          return CustomPaint(
                            painter: _TouchLightPainter(
                              position: _glowPosition,
                              color: widget.glowColor,
                              reach: widget.glowReach,
                              intensity: Curves.easeOutSine.transform(
                                _hold!.value,
                              ),
                              // Cubic: the spread leaves fast and slows as it
                              // reaches the ends, so the pill fills from the
                              // finger outwards instead of everywhere at once.
                              spread: Curves.easeOutCubic.transform(
                                _wash!.value,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                widget.child,
              ],
            ),
            usePackageGlow: false,
          );

    return Listener(
      // A Listener, not a GestureDetector: it never enters the arena, so it
      // cannot take the gesture away from the flex's own recognizer or from
      // anything scrolling above. The flash fires on touch-down regardless of
      // who eventually wins the gesture, which is the point — the surface
      // answers the finger before the finger has decided what it is doing.
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerEnd,
      onPointerCancel: _onPointerEnd,
      child: GestureDetector(onTap: widget.onTap, child: surface),
    );
  }
}

/// The light a finger leaves on a stat pill.
///
/// The package's [GlassGlow] draws a circle sized from the shortest side, and
/// at any brightness worth seeing that circle is *visible as a circle* — a
/// flat disc with an edge, because `plus` clips to white long before the
/// gradient has finished falling. Everything here exists to keep the light
/// round without ever showing where it ends:
///
///  * it is drawn wider than the pill is tall, so its top and bottom are
///    clipped off by the pill and no arc survives;
///  * its peak is a point, not a plateau, and low enough not to clip;
///  * it falls across five stops rather than two, so there is no radius at
///    which the gradient visibly changes its mind.
///
/// [spread] is the release: the same light, let go of the finger, growing
/// until it reaches the farthest corner and fading to nothing as it travels.
class _TouchLightPainter extends CustomPainter {
  const _TouchLightPainter({
    required this.position,
    required this.color,
    required this.reach,
    required this.intensity,
    required this.spread,
  });

  final Offset position;
  final Color color;

  /// Held radius, as a multiple of the shortest side.
  final double reach;

  /// 0 dark, 1 fully lit.
  final double intensity;

  /// 0 held under the finger, 1 arrived at the far corner and gone.
  final double spread;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // The wash carries the light away with it: by the time it has covered the
    // surface there is nothing left to see, so the release needs no separate
    // fade of its own.
    final double alpha = color.a * intensity * (1 - spread);
    if (alpha <= 0.001) return;

    final double held = size.shortestSide * reach;
    final double radius = held + (_farthestCorner(size) - held) * spread;
    final Rect bounds = Rect.fromCircle(center: position, radius: radius);

    canvas.drawCircle(
      position,
      radius,
      Paint()
        // Additive rather than painted over: the glass gets brighter where
        // the light is, instead of being covered by something white.
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: <Color>[
            color.withValues(alpha: alpha),
            color.withValues(alpha: alpha * 0.74),
            color.withValues(alpha: alpha * 0.40),
            color.withValues(alpha: alpha * 0.15),
            color.withValues(alpha: alpha * 0.04),
            color.withValues(alpha: 0),
          ],
          stops: const <double>[0, 0.20, 0.42, 0.64, 0.82, 1],
        ).createShader(bounds),
    );
  }

  /// Distance from the light to the corner it is furthest from — what the
  /// release has to cover before the pill is lit end to end, wherever the
  /// finger happened to be when it left.
  double _farthestCorner(Size size) {
    final double dx = position.dx > size.width / 2
        ? position.dx
        : size.width - position.dx;
    final double dy = position.dy > size.height / 2
        ? position.dy
        : size.height - position.dy;
    return Offset(dx, dy).distance;
  }

  @override
  bool shouldRepaint(_TouchLightPainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.color != color ||
        oldDelegate.reach != reach ||
        oldDelegate.intensity != intensity ||
        oldDelegate.spread != spread;
  }
}
