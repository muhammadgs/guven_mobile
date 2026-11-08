/// The liquid-glass prompts around a press of `Giriş` or `Çıxış`.
///
/// One pane of glass for the whole conversation. Each step — the reminder,
/// the late/early question, the written reason, "not recorded" — is a
/// *stage* of that pane: moving between them cross-fades what is printed on
/// it and lerps its height, with the top edge held still, so the pane grows
/// or shrinks at the bottom and nothing ever jumps.
///
/// Nothing here fades a lens with an `Opacity`: the pane and every capsule
/// fade through `AppGlassSurface.fade`, and text through its colour's alpha
/// (`backdrop-filter-black-flash`).
library;

import 'dart:ui' as ui show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/glass/app_glass.dart';
import '../../../../shared/motion/glass_morph.dart';
import '../../application/attendance_controller.dart';
import '../../domain/attendance.dart';
import '../attendance_metrics.dart';
import '../attendance_style.dart';

/// The steps of the conversation.
enum PromptStage {
  /// `Bu gün hələ giriş etməmisiniz` — Sonra / Giriş.
  reminder,

  /// `Girişdə gecikmə!` — İcazəli / Yazılı bildir.
  reason,

  /// The reason box — Ləğv et / Bildir.
  written,

  /// `Girişiniz qeyd olunmadı.` — Sonra / Giriş. Also how a failed request
  /// is reported, with the server's words in place of that sentence.
  notRecorded,
}

const Duration _kOpen = Duration(milliseconds: 520);
const Duration _kClose = Duration(milliseconds: 300);
const Duration _kStage = Duration(milliseconds: 420);

/// Opens the prompt for [kind] at [start].
///
/// [source] is the rect of a flat button the pane should grow out of (the
/// card's `Giriş`); without one the pane rises in place. [overCard] lightens
/// the wash behind it, because the card is already sitting on one.
Future<void> showAttendancePrompt(
  BuildContext context, {
  required AttendanceController controller,
  required AttendanceKind kind,
  required PromptStage start,
  Rect? source,
  double sourceRadius = 0,
  bool overCard = false,
}) async {
  final PageRouteBuilder<void> route = source == null
      ? PageRouteBuilder<void>(
          opaque: false,
          transitionDuration: _kOpen,
          reverseTransitionDuration: _kClose,
          pageBuilder: (BuildContext context, Animation<double> animation, _) =>
              AttendancePrompt(
                controller: controller,
                kind: kind,
                start: start,
                entrance: animation,
                overCard: overCard,
              ),
        )
      : GlassMorphRoute<void>(
          sourceRect: source,
          sourceRadius: sourceRadius,
          duration: _kOpen,
          reverseDuration: _kClose,
          opaque: false,
          builder: (BuildContext context) => AttendancePrompt(
            controller: controller,
            kind: kind,
            start: start,
            overCard: overCard,
          ),
        );
  await Navigator.of(context).push<void>(route);
}

class AttendancePrompt extends StatefulWidget {
  const AttendancePrompt({
    super.key,
    required this.controller,
    required this.kind,
    required this.start,
    this.entrance,
    this.overCard = false,
  });

  final AttendanceController controller;
  final AttendanceKind kind;
  final PromptStage start;

  /// The route's own animation when it was not pushed as a morph. When it
  /// was, the morph's progress is read from `GlassMorph` instead.
  final Animation<double>? entrance;

  final bool overCard;

  @override
  State<AttendancePrompt> createState() => _AttendancePromptState();
}

class _AttendancePromptState extends State<AttendancePrompt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _swap = AnimationController(
    vsync: this,
    duration: _kStage,
    value: 1,
  );

  late PromptStage _from = widget.start;
  late PromptStage _to = widget.start;

  /// What `notRecorded` says instead of its own sentence, after a failure.
  String? _failure;
  String? _fromFailure;

  final TextEditingController _reason = TextEditingController();
  final FocusNode _reasonFocus = FocusNode();

  /// Set once a press has succeeded and the pane is on its way out, so the
  /// barrier and the back button stop meaning "cancel".
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
    _reason.addListener(_onController);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _swap.dispose();
    _reason.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  void _onController() {
    if (mounted) setState(() {});
  }

  AttendanceKind get _kind => widget.kind;

  bool get _busy => widget.controller.isBusy;

  // ── flow ────────────────────────────────────────────────────────────────

  void _go(PromptStage next, {String? failure}) {
    if (!mounted) return;
    setState(() {
      _from = _to;
      _fromFailure = _failure;
      _to = next;
      _failure = failure;
    });
    _swap.forward(from: 0);
    if (next == PromptStage.written) {
      // The box is only in the tree from the next frame on.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _to == PromptStage.written) _reasonFocus.requestFocus();
      });
    } else {
      _reasonFocus.unfocus();
    }
  }

  /// `Giriş` / `Çıxış` from the reminder or after "not recorded": ask for
  /// a reason when the clock says so, otherwise just press.
  void _act() {
    if (_busy) return;
    if (AttendanceRules.needsReason(_kind, widget.controller.baku)) {
      _go(PromptStage.reason);
    } else {
      _send('');
    }
  }

  Future<void> _send(String note) async {
    if (_busy || _closing) return;
    final String? error = await widget.controller.press(_kind, note);
    if (!mounted) return;
    if (error == null) {
      _closing = true;
      _reasonFocus.unfocus();
      Navigator.of(context).pop();
    } else {
      _go(PromptStage.notRecorded, failure: error);
    }
  }

  /// A tap off the pane, or the back button.
  void _dismiss() {
    if (_busy || _closing) return;
    switch (_to) {
      case PromptStage.reason:
      case PromptStage.written:
        // Walking away from the question is not an answer: say so, and
        // offer the button again.
        _go(PromptStage.notRecorded);
      case PromptStage.reminder:
      case PromptStage.notRecorded:
        _closing = true;
        _reasonFocus.unfocus();
        Navigator.of(context).pop();
    }
  }

  // ── words ───────────────────────────────────────────────────────────────

  String get _title =>
      _kind == AttendanceKind.entry ? 'Girişdə gecikmə!' : 'Erkən çıxış!';

  List<_Line> _lines(PromptStage stage, String? failure) {
    final bool entry = _kind == AttendanceKind.entry;
    return switch (stage) {
      PromptStage.reminder => <_Line>[
        _Line(
          entry
              ? 'Bu gün hələ giriş etməmisiniz'
              : 'Bu gün hələ çıxış etməmisiniz',
        ),
      ],
      PromptStage.reason => <_Line>[
        _Line(_title, bold: true),
        _Line(
          entry ? '09:00-dan gec gəlmisiniz.' : '18:00-dan tez çıxırsınız.',
        ),
        const _Line('Səbəbinizi bildirin:'),
      ],
      PromptStage.written => <_Line>[_Line(_title, bold: true)],
      PromptStage.notRecorded => <_Line>[
        _Line(
          failure ??
              (entry ? 'Girişiniz qeyd olunmadı.' : 'Çıxışınız qeyd olunmadı.'),
        ),
      ],
    };
  }

  // ── geometry ────────────────────────────────────────────────────────────

  TextStyle _style(AttendanceMetrics m, _Line line, double presence) =>
      attendanceText(
        m.type(AttendanceMetrics.promptSize),
        line: AttendanceMetrics.promptLine,
        weight: line.bold ? FontWeight.w600 : FontWeight.w400,
        color: kAttendanceInk.withValues(alpha: presence),
      );

  double _textHeight(AttendanceMetrics m, List<_Line> lines) {
    double sum = 0;
    for (final _Line line in lines) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: line.text, style: _style(m, line, 1)),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        textScaler: m.textScaler,
      )..layout(maxWidth: m.promptTextWidth);
      sum += painter.height;
      painter.dispose();
    }
    return sum;
  }

  double _heightOf(AttendanceMetrics m, PromptStage stage, String? failure) {
    if (stage == PromptStage.written) {
      return m.writtenPromptHeightFor(_textHeight(m, _lines(stage, failure)));
    }
    return m.promptPadTop +
        _textHeight(m, _lines(stage, failure)) +
        m.promptGapToButtons +
        m.promptButtonHeight +
        m.promptPadBottom;
  }

  @override
  Widget build(BuildContext context) {
    final AttendanceMetrics m = AttendanceMetrics.of(context);
    final GlassMorph? morph = GlassMorph.maybeOf(context);
    final Animation<double> entrance =
        morph?.progress ?? widget.entrance ?? kAlwaysCompleteAnimation;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _dismiss();
      },
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[entrance, _swap]),
          builder: (BuildContext context, _) {
            final double e = entrance.value.clamp(0.0, 1.0);
            final double swap = Curves.easeOutCubic.transform(_swap.value);
            final double height = ui.lerpDouble(
              _heightOf(m, _from, _fromFailure),
              _heightOf(m, _to, _failure),
              swap,
            )!;
            final Rect rest = m.promptRect(height);

            // Where the pane is this frame, and how much of it is there.
            Rect rect;
            double radius = m.promptRadius;
            double glass;
            double content;
            if (morph != null) {
              final GlassMorphFrame frame = resolveGlassMorph(
                progress: entrance,
                from: morph.sourceRect,
                fromRadius: morph.sourceRadius,
                to: rest,
                toRadius: m.promptRadius,
              );
              rect = frame.rect;
              radius = frame.radius;
              glass = (frame.blend / 0.3).clamp(0.0, 1.0);
              content = frame.targetOpacity;
            } else {
              final bool back = entrance.status == AnimationStatus.reverse;
              final double grow = back
                  ? Curves.easeInCubic.transform(e)
                  : Curves.easeOutBack.transform(e);
              final double size = ui.lerpDouble(0.88, 1, grow)!;
              rect = Rect.fromCenter(
                center: rest.center,
                width: rest.width * size,
                height: rest.height * size,
              );
              glass = Curves.easeOut.transform((e / 0.5).clamp(0.0, 1.0));
              content = back
                  ? Curves.easeIn.transform(e)
                  : Curves.easeOut.transform(((e - 0.3) / 0.7).clamp(0, 1));
            }

            final double outgoing =
                1 - Curves.easeIn.transform((_swap.value / 0.45).clamp(0, 1));
            final double incoming = Curves.easeOut.transform(
              ((_swap.value - 0.3) / 0.7).clamp(0.0, 1.0),
            );

            return Stack(
              children: <Widget>[
                Positioned.fill(
                  child: AttendanceScrim(
                    amount: e,
                    overCard: widget.overCard,
                    onTap: _dismiss,
                  ),
                ),
                Positioned.fromRect(
                  rect: rect,
                  child: AppGlassSurface(
                    style: glassAtRadius(kPromptGlass, radius),
                    cornerRadius: radius,
                    fade: glass,
                    child: const SizedBox.expand(),
                  ),
                ),
                // The words and the capsules, laid out at rest and clipped
                // to the pane while it is still growing. Siblings of the
                // pane rather than its child, so no glass nests in glass.
                Positioned.fromRect(
                  rect: rect,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      minWidth: rest.width,
                      maxWidth: rest.width,
                      minHeight: 0,
                      maxHeight: double.infinity,
                      child: SizedBox(
                        width: rest.width,
                        height: height,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: <Widget>[
                            if (_swap.value < 1 && _from != _to)
                              _stage(
                                m,
                                _from,
                                _fromFailure,
                                outgoing * content,
                                interactive: false,
                              ),
                            _stage(
                              m,
                              _to,
                              _failure,
                              (_from == _to ? 1 : incoming) * content,
                              interactive: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _stage(
    AttendanceMetrics m,
    PromptStage stage,
    String? failure,
    double presence, {
    required bool interactive,
  }) {
    final List<_Line> lines = _lines(stage, failure);
    final double height = _heightOf(m, stage, failure);

    final Widget words = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final _Line line in lines)
          Text(
            line.text,
            textAlign: TextAlign.center,
            style: _style(m, line, presence),
          ),
      ],
    );

    final Widget body;
    if (stage == PromptStage.written) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(height: m.promptPadTop),
          words,
          SizedBox(height: m.fieldGapAbove),
          _ReasonField(
            metrics: m,
            controller: _reason,
            focus: _reasonFocus,
            presence: presence,
            enabled: interactive,
          ),
          SizedBox(height: m.fieldGapBelow),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              _PromptButton(
                metrics: m,
                label: 'Ləğv et',
                tint: kPromptPlainTint,
                width: m.smallButtonWidth,
                presence: presence,
                onTap: interactive ? _dismiss : null,
              ),
              SizedBox(width: m.smallButtonGap),
              _PromptButton(
                metrics: m,
                label: 'Bildir',
                tint: kPromptPlainTint,
                width: m.smallButtonWidth,
                presence: presence,
                enabled: _reason.text.trim().isNotEmpty,
                busy: interactive && _busy,
                onTap: interactive ? () => _send(_reason.text.trim()) : null,
              ),
            ],
          ),
        ],
      );
    } else {
      final (String, Color, VoidCallback) left;
      final (String, Color, VoidCallback) right;
      switch (stage) {
        case PromptStage.reason:
          left = (
            'İcazəli',
            kPromptPlainTint,
            () => _send(AttendanceRules.permittedNote),
          );
          right = (
            'Yazılı bildir',
            kPromptPlainTint,
            () => _go(PromptStage.written),
          );
        case PromptStage.reminder:
        case PromptStage.notRecorded:
        case PromptStage.written:
          left = ('Sonra', kPromptPlainTint, _dismiss);
          right = (_kind.label, promptTintFor(_kind), _act);
      }
      // Which one turns into a spinner while the request runs: the one
      // that sent it.
      final bool leftSends = stage == PromptStage.reason;
      body = Column(
        children: <Widget>[
          SizedBox(height: m.promptPadTop),
          words,
          SizedBox(height: m.promptGapToButtons),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _PromptButton(
                metrics: m,
                label: left.$1,
                tint: left.$2,
                width: m.promptButtonWidth,
                presence: presence,
                busy: interactive && _busy && leftSends,
                onTap: interactive ? left.$3 : null,
              ),
              SizedBox(width: m.promptButtonGap),
              _PromptButton(
                metrics: m,
                label: right.$1,
                tint: right.$2,
                width: m.promptButtonWidth,
                presence: presence,
                busy: interactive && _busy && !leftSends,
                onTap: interactive ? right.$3 : null,
              ),
            ],
          ),
        ],
      );
    }

    return Positioned(
      // Keyed by stage, so a stage keeps its state — the reason box its
      // focus — when the one fading out ahead of it leaves the stack.
      key: ValueKey<PromptStage>(stage),
      left: 0,
      right: 0,
      top: 0,
      height: height,
      child: IgnorePointer(
        ignoring: !interactive,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: m.promptSidePad),
          child: body,
        ),
      ),
    );
  }
}

class _Line {
  const _Line(this.text, {this.bold = false});

  final String text;
  final bool bold;
}

/// The wash over everything behind a prompt or the card: a blur and a grey,
/// both growing with [amount]. A tap on it is [onTap].
class AttendanceScrim extends StatelessWidget {
  const AttendanceScrim({
    super.key,
    required this.amount,
    required this.onTap,
    this.overCard = false,
  });

  final double amount;
  final VoidCallback onTap;
  final bool overCard;

  @override
  Widget build(BuildContext context) {
    final double t = amount.clamp(0.0, 1.0);
    final double sigma =
        (overCard ? kAttendanceBlurOverCard : kAttendanceBlur) * t;
    final Color wash = overCard ? kAttendanceScrimOverCard : kAttendanceScrim;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: ColoredBox(color: wash.withValues(alpha: wash.a * t)),
        ),
      ),
    );
  }
}

/// A capsule on the prompt: glass, a label, a press that dips it.
class _PromptButton extends StatefulWidget {
  const _PromptButton({
    required this.metrics,
    required this.label,
    required this.tint,
    required this.width,
    required this.presence,
    required this.onTap,
    this.enabled = true,
    this.busy = false,
  });

  final AttendanceMetrics metrics;
  final String label;
  final Color tint;
  final double width;
  final double presence;
  final VoidCallback? onTap;
  final bool enabled;
  final bool busy;

  @override
  State<_PromptButton> createState() => _PromptButtonState();
}

class _PromptButtonState extends State<_PromptButton> {
  bool _down = false;

  void _press(bool down) {
    if (_down == down) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final AttendanceMetrics m = widget.metrics;
    final double h = m.promptButtonHeight;
    final double p = widget.presence.clamp(0.0, 1.0);
    final bool live = widget.onTap != null && widget.enabled && !widget.busy;
    final Color ink = kAttendanceInk.withValues(
      alpha: p * (widget.enabled ? 1 : 0.35),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: live ? (_) => _press(true) : null,
      onTapUp: live ? (_) => _press(false) : null,
      onTapCancel: () => _press(false),
      onTap: live
          ? () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.95 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: SizedBox(
          width: widget.width,
          height: h,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              AppGlassSurface(
                style: glassAtRadius(promptButtonGlass(widget.tint), h / 2),
                cornerRadius: h / 2,
                backend: AppGlassBackend.easy,
                fade: p,
                child: const SizedBox.expand(),
              ),
              Center(
                child: widget.busy
                    ? SizedBox(
                        width: h * 0.42,
                        height: h * 0.42,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(ink),
                        ),
                      )
                    : Padding(
                        padding: EdgeInsets.symmetric(horizontal: h * 0.25),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            style: attendanceText(
                              m.type(AttendanceMetrics.promptSize),
                              line: 1.2,
                              color: ink,
                            ),
                          ),
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

/// `Səbəbim…` — the written reason, on a whiter pane of its own.
class _ReasonField extends StatelessWidget {
  const _ReasonField({
    required this.metrics,
    required this.controller,
    required this.focus,
    required this.presence,
    required this.enabled,
  });

  final AttendanceMetrics metrics;
  final TextEditingController controller;
  final FocusNode focus;
  final double presence;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final AttendanceMetrics m = metrics;
    final double p = presence.clamp(0.0, 1.0);
    final TextStyle typing = attendanceText(
      m.type(AttendanceMetrics.fieldSize),
      line: 1.35,
      color: kAttendanceInk.withValues(alpha: p),
    );
    return SizedBox(
      height: m.fieldHeight,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          AppGlassSurface(
            style: glassAtRadius(
              promptButtonGlass(kPromptFieldTint),
              m.fieldRadius,
            ),
            cornerRadius: m.fieldRadius,
            backend: AppGlassBackend.easy,
            fade: p,
            child: const SizedBox.expand(),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: m.fieldPadH,
              vertical: m.fieldPadV,
            ),
            child: TextField(
              controller: controller,
              focusNode: focus,
              enabled: enabled,
              maxLines: null,
              expands: true,
              maxLength: 250,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              cursorColor: kAttendanceInk,
              style: typing,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                counterText: '',
                hintText: 'Səbəbim...',
                hintStyle: typing.copyWith(
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF6E6E6E).withValues(alpha: p),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
