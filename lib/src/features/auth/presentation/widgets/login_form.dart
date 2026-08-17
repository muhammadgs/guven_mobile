import 'package:flutter/material.dart';

import '../../../../shared/layout.dart';
import '../../application/session_controller.dart';

/// What lives inside the login card: title, two fields, the submit button and
/// a slot for whatever the server said when it refused.
///
/// Laid out against the card's *resting* size — the morph re-parents this
/// subtree without rebuilding it (see `_GlassCard`), so nothing here may
/// depend on the in-flight rect.
class LoginForm extends StatefulWidget {
  const LoginForm({
    super.key,
    required this.titleSize,
    required this.labelSize,
    required this.fieldHeight,
  });

  final double titleSize;
  final double labelSize;
  final double fieldHeight;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final TextEditingController _login = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  /// Set when the user submits an empty field — a local complaint, shown in
  /// the same slot as the server's.
  String? _localError;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final SessionController session = SessionScope.read(context);
    if (session.isBusy) return;

    final String login = _login.text.trim();
    final String password = _password.text;
    if (login.isEmpty || password.isEmpty) {
      setState(() => _localError = 'Email/nömrə və şifrəni daxil edin.');
      return;
    }

    setState(() => _localError = null);
    FocusScope.of(context).unfocus();
    // On success the session flips to signedIn and the root swaps this whole
    // flow out, so there is nothing to do here but let it happen. On failure
    // the controller notifies and the error slot below picks the message up.
    await session.signIn(login: login, password: password);
  }

  @override
  Widget build(BuildContext context) {
    final SessionController session = SessionScope.of(context);
    final String? message = _localError ?? session.error;

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
            fontSize: widget.titleSize,
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
        SizedBox(height: scaled(context, 34)),
        _GlassLoginField(
          label: 'Email və ya nömrə',
          controller: _login,
          fieldHeight: widget.fieldHeight,
          labelSize: widget.labelSize,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _passwordFocus.requestFocus(),
        ),
        SizedBox(height: scaled(context, 18)),
        _GlassLoginField(
          label: 'Şifrə',
          controller: _password,
          focusNode: _passwordFocus,
          fieldHeight: widget.fieldHeight,
          labelSize: widget.labelSize,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        // A fixed slot, so a message appearing does not shove the button
        // around inside glass that is not allowed to resize.
        SizedBox(
          height: scaled(context, 40),
          child: Center(
            child: AnimatedOpacity(
              opacity: message == null ? 0 : 1,
              duration: const Duration(milliseconds: 180),
              child: Text(
                message ?? '',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: const Color(0xFFFFD9D6),
                  fontFamily: 'Poppins',
                  fontSize: scaled(context, 13),
                  height: 1.25,
                  shadows: const <Shadow>[
                    Shadow(color: Color(0x66000000), blurRadius: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
        Center(
          child: _LoginButton(
            width: scaled(context, 180),
            height: scaled(context, 52),
            busy: session.isBusy,
            onTap: _submit,
          ),
        ),
      ],
    );
  }
}

class _GlassLoginField extends StatelessWidget {
  const _GlassLoginField({
    required this.label,
    required this.controller,
    required this.fieldHeight,
    required this.labelSize,
    this.focusNode,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final double fieldHeight;
  final double labelSize;
  final FocusNode? focusNode;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

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
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            autocorrect: false,
            enableSuggestions: !obscureText,
            cursorColor: Colors.white,
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
                borderSide: const BorderSide(color: Colors.white, width: 2.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: const BorderSide(color: Colors.white, width: 2.6),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: const BorderSide(color: Colors.white, width: 2.2),
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
    required this.busy,
    required this.onTap,
  });

  final double width;
  final double height;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
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
            child: busy
                ? SizedBox(
                    width: height * 0.42,
                    height: height * 0.42,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
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
