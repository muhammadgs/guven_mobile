import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../../shared/effects.dart';
import '../../../shared/layout.dart';
import '../../../shared/motion/glass_morph.dart';
import '../../../shared/motion/glass_shimmer.dart';
import 'widgets/auth_glass.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      // The card places itself. It has to be free to sit anywhere between the
      // start button's rect and its own, which no Center can express, and a
      // Scaffold resize underneath that would fight the morph — so the
      // keyboard is handled in `_restingRect` instead.
      resizeToAvoidBottomInset: false,
      body: _MorphingLoginCard(),
    );
  }
}

/// The login card, drawn wherever the morph currently has it.
///
/// Pushed through a [GlassMorphRoute] this is the *same* lens the start
/// button was: it opens at the button's rect wearing the button's glass and
/// grows into the card. Pushed any other way there is no [GlassMorph] to
/// find and it simply builds at rest.
class _MorphingLoginCard extends StatelessWidget {
  const _MorphingLoginCard();

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final double cardWidth = (screen.width - scaled(context, 56))
        .clamp(320.0, scaled(context, 440))
        .toDouble();
    final double cardHeight = (screen.height * 0.48)
        .clamp(scaled(context, 460), scaled(context, 500))
        .toDouble();
    final double cardRadius = scaled(context, 56);

    final Rect resting = _restingRect(context, Size(cardWidth, cardHeight));

    final Widget content = Padding(
      padding: EdgeInsets.fromLTRB(
        scaled(context, 34),
        scaled(context, 22),
        scaled(context, 34),
        scaled(context, 26),
      ),
      child: _LoginCardContent(
        titleSize: responsive(context, factor: 0.105, min: 38, max: 56),
        labelSize: responsive(context, factor: 0.045, min: 18, max: 24),
        fieldHeight: (screen.height * 0.068)
            .clamp(scaled(context, 56), scaled(context, 64))
            .toDouble(),
      ),
    );

    final GlassMorph? morph = GlassMorph.maybeOf(context);
    if (morph == null) {
      return _AuthSurface(
        frame: GlassMorphFrame.settled(resting, cardRadius),
        resting: resting,
        content: content,
      );
    }

    return AnimatedBuilder(
      animation: morph.progress,
      // Hoisted: the form is built once and only the wrappers around it are
      // rebuilt per frame, so the fields keep their state (and their cost)
      // out of the animation.
      child: content,
      builder: (context, child) {
        return _AuthSurface(
          frame: resolveGlassMorph(
            progress: morph.progress,
            from: morph.sourceRect,
            fromRadius: morph.sourceRadius,
            to: resting,
            toRadius: cardRadius,
          ),
          resting: resting,
          content: child!,
        );
      },
    );
  }
}

/// The card, plus the back button that blooms in beside it once it lands.
class _AuthSurface extends StatelessWidget {
  const _AuthSurface({
    required this.frame,
    required this.resting,
    required this.content,
  });

  final GlassMorphFrame frame;

  /// Where the card sits once it has landed. The back button is anchored to
  /// this rather than to the in-flight one, so it does not ride the bloom.
  final Rect resting;

  final Widget content;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.paddingOf(context);

    // Rides the form's fade rather than its own clock, so pressing back
    // shrinks it away at the same moment the card starts collapsing. Grown by
    // *size*, not by an Opacity or a Transform — see [_GlassCard].
    final double appear = Curves.easeOutBack.transform(
      ((frame.targetOpacity - 0.15) / 0.85).clamp(0.0, 1.0),
    );
    final double full = scaled(context, 46);
    final double gap = scaled(context, 14);
    final double backSize = full * appear;

    // Just above the card's top-left corner, tucked under the notch if the
    // card sits high. Positioned by its centre so it blooms outwards.
    final Offset anchor = Offset(
      resting.left + full / 2,
      math.max(safe.top + gap + full / 2, resting.top - gap - full / 2),
    );

    return Stack(
      children: <Widget>[
        Positioned.fromRect(
          rect: frame.rect,
          child: _GlassCard(
            frame: frame,
            restingSize: resting.size,
            content: content,
          ),
        ),
        if (backSize > 1)
          Positioned(
            left: anchor.dx - backSize / 2,
            top: anchor.dy - backSize / 2,
            child: GlassPressButton(
              width: backSize,
              height: backSize,
              cornerRadius: backSize / 2,
              style: kAuthBackGlass,
              shadow: kAuthBackShadow,
              onTap: () => Navigator.of(context).maybePop(),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white.withValues(
                  alpha: appear.clamp(0.0, 1.0),
                ),
                size: scaled(context, 19),
              ),
            ),
          ),
      ],
    );
  }
}

/// Where the card sits when nothing is moving: centred in what the system
/// chrome and the keyboard leave behind.
///
/// Computed rather than laid out, because the morph needs this rect in the
/// same global coordinates as the button it grows from.
Rect _restingRect(BuildContext context, Size card) {
  final Size screen = MediaQuery.sizeOf(context);
  final EdgeInsets safe = MediaQuery.paddingOf(context);
  final double keyboard = MediaQuery.viewInsetsOf(context).bottom;

  final Rect free = Rect.fromLTRB(
    safe.left,
    safe.top,
    screen.width - safe.right,
    screen.height - math.max(safe.bottom, keyboard),
  );
  final Rect centred = Rect.fromCenter(
    center: free.center,
    width: card.width,
    height: card.height,
  );

  // With the keyboard up the free strip can be shorter than the card. Pin the
  // top rather than let the title slide under the status bar.
  return centred.top < free.top
      ? Rect.fromLTWH(centred.left, free.top, card.width, card.height)
      : centred;
}

/// One lens, two contents.
///
/// Nothing here ever wraps the lens in an `Opacity` or an `ImageFiltered`:
/// either would put the lens inside a `saveLayer`, leaving its
/// `BackdropFilter` sampling that empty layer instead of the video behind
/// the app — which is the black flash. Only what sits *inside* the glass
/// fades.
class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.frame,
    required this.restingSize,
    required this.content,
  });

  final GlassMorphFrame frame;

  /// The card's size at rest. The form is always laid out against this, never
  /// against the in-flight rect — a login form reflowing inside a 70pt pill
  /// would overflow on every frame of the way out.
  final Size restingSize;

  final Widget content;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(frame.radius),
        boxShadow: BoxShadow.lerpList(
          kStartCtaShadow,
          kLoginCardShadow,
          frame.blend,
        ),
      ),
      // No `touch` flex on the card: it wraps text fields, and a deforming
      // surface under a keyboard-bound input reads wrong. The shimmer the
      // finger started on the button does carry through, though — it is
      // lighting, not deformation.
      child: LiquidGlassLens(
        style: shimmerLiquidGlassStyle(
          lerpLiquidGlassStyle(
            kStartCtaGlass,
            kLoginCardGlass,
            frame.blend,
            cornerRadius: frame.radius,
          ),
          frame.shimmer,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Center(
              child: Opacity(
                opacity: frame.sourceOpacity,
                child: blurred(
                  7 * (1 - frame.sourceOpacity),
                  const StartCtaLabel(),
                ),
              ),
            ),
            IgnorePointer(
              ignoring: !frame.isSettled,
              child: OverflowBox(
                minWidth: restingSize.width,
                maxWidth: restingSize.width,
                minHeight: restingSize.height,
                maxHeight: restingSize.height,
                child: Opacity(
                  opacity: frame.targetOpacity,
                  child: blurred(
                    12 * (1 - frame.targetOpacity),
                    Transform.translate(
                      offset: Offset(0, 18 * (1 - frame.targetOpacity)),
                      child: content,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginCardContent extends StatelessWidget {
  const _LoginCardContent({
    required this.titleSize,
    required this.labelSize,
    required this.fieldHeight,
  });

  final double titleSize;
  final double labelSize;
  final double fieldHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Giriş',
          textAlign: TextAlign.center,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'CalSans',
            fontSize: titleSize,
            fontWeight: FontWeight.w400,
            height: 1,
            letterSpacing: -0.8,
            shadows: const <Shadow>[
              Shadow(
                color: Color(0x33000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
        ),
        SizedBox(height: scaled(context, 38)),
        _GlassLoginField(
          label: 'Email və ya nömrə',
          fieldHeight: fieldHeight,
          labelSize: labelSize,
          keyboardType: TextInputType.emailAddress,
        ),
        SizedBox(height: scaled(context, 20)),
        _GlassLoginField(
          label: 'Şifrə',
          fieldHeight: fieldHeight,
          labelSize: labelSize,
          obscureText: true,
        ),
        SizedBox(height: scaled(context, 24)),
        Center(
          child: _LoginButton(
            width: scaled(context, 180),
            height: scaled(context, 52),
            onTap: () {},
          ),
        ),
      ],
    );
  }
}

class _GlassLoginField extends StatelessWidget {
  const _GlassLoginField({
    required this.label,
    required this.fieldHeight,
    required this.labelSize,
    this.obscureText = false,
    this.keyboardType,
  });

  final String label;
  final double fieldHeight;
  final double labelSize;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(left: scaled(context, 26)),
          child: Text(
            label,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Poppins',
              fontSize: labelSize,
              fontWeight: FontWeight.w400,
              height: 1.1,
              letterSpacing: -0.25,
            ),
          ),
        ),
        SizedBox(height: scaled(context, 12)),
        SizedBox(
          height: fieldHeight,
          child: TextField(
            obscureText: obscureText,
            keyboardType: keyboardType,
            cursorColor: Colors.white,
            textInputAction:
                obscureText ? TextInputAction.done : TextInputAction.next,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Poppins',
              fontSize: scaled(context, 20),
              fontWeight: FontWeight.w400,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0x08000000),
              contentPadding: EdgeInsets.symmetric(
                horizontal: scaled(context, 24),
                vertical: scaled(context, 16),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: const BorderSide(
                  color: Colors.white,
                  width: 2.2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: const BorderSide(
                  color: Colors.white,
                  width: 2.6,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: const BorderSide(
                  color: Colors.white,
                  width: 2.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.width,
    required this.height,
    required this.onTap,
  });

  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x60FFFFFF),
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 20,
              spreadRadius: -8,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: SizedBox(
          width: width,
          height: height,
          child: Center(
            child: Text(
              'Daxil olun',
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
                fontSize: scaled(context, 20),
                fontWeight: FontWeight.w400,
                height: 1,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
