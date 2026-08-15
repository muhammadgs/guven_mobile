import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../../../shared/layout.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final double cardWidth = (screen.width - scaled(context, 56))
        .clamp(320.0, scaled(context, 440))
        .toDouble();
    final double cardHeight = (screen.height * 0.48)
        .clamp(scaled(context, 460), scaled(context, 500))
        .toDouble();
    final double titleSize =
        responsive(context, factor: 0.105, min: 38, max: 56);
    final double labelSize =
        responsive(context, factor: 0.045, min: 18, max: 24);
    final double fieldHeight = (screen.height * 0.068)
        .clamp(scaled(context, 56), scaled(context, 64))
        .toDouble();
    final double cardRadius = scaled(context, 56);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: scaled(context, 24)),
            child: SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(cardRadius),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color.fromARGB(82, 0, 0, 0),
                      blurRadius: 42,
                      spreadRadius: -12,
                      offset: Offset(0, 26),
                    ),
                  ],
                ),
                child: LiquidGlassLayer(
                  settings: const LiquidGlassSettings(
                    thickness: 45,
                    blur: 0,
                    glassColor: Color.fromARGB(0, 179, 179, 179),
                    refractiveIndex: 1.45,
                    lightIntensity: 1.35,
                    ambientStrength: 0.55,
                    saturation: 1.20,
                  ),
                  child: LiquidGlass(
                    shape: LiquidRoundedSuperellipse(
                      borderRadius: cardRadius,
                    ),
                    glassContainsChild: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        scaled(context, 34),
                        scaled(context, 22),
                        scaled(context, 34),
                        scaled(context, 26),
                      ),
                      child: _LoginCardContent(
                        titleSize: titleSize,
                        labelSize: labelSize,
                        fieldHeight: fieldHeight,
                      ),
                    ),
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
