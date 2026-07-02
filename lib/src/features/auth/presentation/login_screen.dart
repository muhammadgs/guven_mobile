import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final double cardWidth = (screen.width - 56).clamp(320.0, 440.0).toDouble();
    final double cardMinHeight =
        (screen.height * 0.58).clamp(430.0, 540.0).toDouble();
    final double titleSize =
        (screen.width * 0.105).clamp(38.0, 56.0).toDouble();
    final double labelSize =
        (screen.width * 0.045).clamp(18.0, 24.0).toDouble();
    final double fieldHeight =
        (screen.height * 0.074).clamp(58.0, 72.0).toDouble();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(56),
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
                    borderRadius: 56,
                  ),
                  glassContainsChild: false,
                  child: SizedBox(
                    width: cardWidth,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: cardMinHeight),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(34, 30, 34, 34),
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
        const SizedBox(height: 56),
        _GlassLoginField(
          label: 'Email və ya nömrə',
          fieldHeight: fieldHeight,
          labelSize: labelSize,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 26),
        _GlassLoginField(
          label: 'Şifrə',
          fieldHeight: fieldHeight,
          labelSize: labelSize,
          obscureText: true,
        ),
        const SizedBox(height: 32),
        Center(
          child: _LoginButton(
            width: 180,
            height: 54,
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
          padding: const EdgeInsets.only(left: 26),
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
        const SizedBox(height: 14),
        SizedBox(
          height: fieldHeight,
          child: TextField(
            obscureText: obscureText,
            keyboardType: keyboardType,
            cursorColor: Colors.white,
            textInputAction:
                obscureText ? TextInputAction.done : TextInputAction.next,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w400,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0x08000000),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
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
          child: const Center(
            child: Text(
              'Daxil olun',
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
                fontSize: 20,
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
