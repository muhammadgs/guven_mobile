import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../domain/bank_account.dart';
import '../../domain/database_filter.dart' show tidySpaces;
import '../database_format.dart';
import 'cash_desk_card.dart';
import 'database_card.dart';
import 'database_glass.dart';
import 'team_card.dart';

/// One bank account, shut or open.
///
/// Shut, it is the design's first card: the code, the account's name, and
/// under them the bank, the number and the currency, bare. Tapping it opens
/// it into the design's second card: `Hesab adı:` comes in over the name and
/// `Hesab nömrəsi:` over the number, the bank and the currency take their
/// labels ahead of them — `Bank:` and `Valyuta:`, the one the design forgot
/// (the user, 2026-10-08) — and under them grow in how many payments went
/// through the account, what came in, what went out, the balance, the kind
/// and the status. Like the other `Baza` cards it does not swap one
/// arrangement for the other: the shut card's lines stay on screen and move
/// to their new places while the lines only an open card has grow into the
/// room made for them.
///
/// The faces, sizes and edges are `Kassalar`'s, which are `Komanda`'s
/// ([TeamCard]): the code ChakraPetch at 14, its baseline 27.5pt down; the
/// name CalSans at 22 on 29pt lines, taking every line it needs; Poppins at
/// 14 for the rest; the last line 22pt above the bottom edge.
///
/// And so is the spacing. The design's gaps wander — 16 to 22pt from one
/// line to the next — and the user's word is that they are meant to be one
/// gap, as on the other pages: every line stands [CashDeskCard.kSeenGap]
/// from the one above it, measured as it is seen, from a baseline to the
/// capitals under it — the design's own average, 19.2pt, and `Kassalar`'s.
/// A label over its value is closer, as drawn: [kLabelSeenGap]. A one-line
/// name makes a 171.1pt shut card and a 383.5pt open one.
class BankAccountCard extends StatefulWidget {
  const BankAccountCard({
    super.key,
    required this.account,
    required this.expanded,
    required this.onToggle,
    required this.loading,
    required this.onRetry,
    this.error,
  });

  /// The row, with the account's own answer laid over it once that is
  /// known.
  final BankAccount account;

  /// Whether the card is open. Owned by the list, not the card, so a card
  /// scrolled far enough away to be rebuilt comes back the way it was left.
  final bool expanded;

  final VoidCallback onToggle;

  /// True while the account's own answer is on its way.
  final bool loading;

  /// Why the account's own answer could not be read, or null.
  final String? error;

  /// Asks for the account's own answer again after [error].
  final VoidCallback onRetry;

  /// From a label's baseline to the capitals of the value under it: the
  /// design draws 8.6pt over the name and 10.2 over the number, one gap
  /// drawn twice; it is their mean.
  static const double kLabelSeenGap = (8.6 + 10.23) / 2;

  /// From the code's line to the name's, shut — `Kassalar`'s — and open,
  /// with `Hesab adı:` between them: a row's 29pt under the code, and the
  /// name [kLabelSeenGap] under it.
  static const double kNameBlockShut = CashDeskCard.kCodeGap;
  static const double kNameBlockOpen = 27.804;

  /// Where `Hesab adı:`'s line starts under the code's: 29pt baseline to
  /// baseline, as a row under the code would.
  static const double kNameLabelTop = 11.89;

  /// From the bank's line to the number's, shut — a row's — and open, with
  /// `Hesab nömrəsi:` a row under the bank and the number [kLabelSeenGap]
  /// under it.
  static const double kNumberBlockShut = TeamCard.kRowGap;
  static const double kNumberBlockOpen = 31.186;

  /// Where `Hesab nömrəsi:`'s line starts under the bank's: a row's gap.
  static const double kNumberLabelTop = TeamCard.kRowGap;

  @override
  State<BankAccountCard> createState() => _BankAccountCardState();
}

class _BankAccountCardState extends State<BankAccountCard>
    with SingleTickerProviderStateMixin {
  // `Satışlar`' timing, so the lists open alike.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 360),
    value: widget.expanded ? 1 : 0,
  );

  late final Animation<double> _open = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInOutCubic,
  );

  @override
  void didUpdateWidget(covariant BankAccountCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded == oldWidget.expanded) return;
    if (widget.expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double s = databaseScale(context);

    return Semantics(
      button: true,
      expanded: widget.expanded,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggle,
        child: DatabaseCardSurface(
          padding: EdgeInsets.fromLTRB(
            TeamCard.kPadH * s,
            TeamCard.kPadTop * s,
            TeamCard.kPadH * s,
            TeamCard.kPadBottom * s,
          ),
          child: AnimatedBuilder(
            animation: _open,
            builder: (BuildContext context, _) => _Body(
              account: widget.account,
              t: _open.value,
              scale: s,
              loading: widget.loading,
              error: widget.error,
              onRetry: widget.onRetry,
            ),
          ),
        ),
      ),
    );
  }
}

/// The card's contents at [t] of the way open: one column in both states,
/// so the blend is a matter of gaps and of labels coming in, and at 0 and 1
/// it is exactly one of the two designs.
class _Body extends StatelessWidget {
  const _Body({
    required this.account,
    required this.t,
    required this.scale,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final BankAccount account;
  final double t;
  final double scale;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final double fade = databaseCardFade(t);
    final bool opening = t > 0;
    final TextStyle body = databaseCardStyle(14 * s);
    final BankAccount account = this.account;
    final String? error = this.error;
    final bool? active = account.active;

    // What only the account's own answer says: `…` while it is on its way,
    // and `—` when it says nothing — or could not be read.
    String detail(String? Function(BankAccount) of) {
      if (loading) return '…';
      return of(account) ?? kUnknownValue;
    }

    String? money(double? value) {
      if (value == null) return null;
      // The design's `0.00 ₼` for manat; any other currency by its code,
      // as the website writes every one.
      return account.currency == kBankAccountCurrency
          ? formatMoney(value)
          : '${formatDecimal(value)} ${account.currency}';
    }

    final Widget rowGap = SizedBox(height: TeamCard.kRowGap * s);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          // A code with its tail missing names another account; one too
          // wide for the card is set smaller instead.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              account.code ?? kUnknownValue,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontFamily: kDatabaseFigureFont,
                fontSize: 14 * s,
                height: 1.2,
                letterSpacing: 0,
                color: kGlassInk,
              ),
            ),
          ),
        ),
        _LabelOver(
          label: 'Hesab adı:',
          top: BankAccountCard.kNameLabelTop * s,
          shut: BankAccountCard.kNameBlockShut * s,
          open: BankAccountCard.kNameBlockOpen * s,
          style: body,
          t: t,
          fade: fade,
        ),
        // Every line it needs.
        Text(
          _given(account.name) ?? kUnknownValue,
          style: TeamCard.nameStyle(s),
        ),
        SizedBox(height: CashDeskCard.kNameGap * s),
        _LabelledLine(
          // A space, as the design sets every label from its value; a hard
          // one, so it is measured rather than dropped at the label's end.
          label: 'Bank: ',
          value: _given(account.bankName) ?? kUnknownValue,
          style: body,
          t: t,
          fade: fade,
        ),
        _LabelOver(
          label: 'Hesab nömrəsi:',
          top: BankAccountCard.kNumberLabelTop * s,
          shut: BankAccountCard.kNumberBlockShut * s,
          open: BankAccountCard.kNumberBlockOpen * s,
          style: body,
          t: t,
          fade: fade,
        ),
        _Line(text: _given(account.number) ?? kUnknownValue, style: body),
        rowGap,
        _LabelledLine(
          label: 'Valyuta: ',
          value: account.currency,
          style: body,
          t: t,
          fade: fade,
        ),
        if (opening)
          DatabaseCardReveal(
            t: t,
            fade: fade,
            children: <Widget>[
              rowGap,
              _Pair(
                label: 'Ödəniş sayı:',
                value: detail((BankAccount a) {
                  final int? count = a.paymentsCount;
                  return count == null ? null : formatCount(count);
                }),
                pending: loading,
                style: body,
              ),
              rowGap,
              _Pair(
                label: 'Daxil olan:',
                value: detail((BankAccount a) => money(a.totalIn)),
                pending: loading,
                style: body,
              ),
              rowGap,
              _Pair(
                label: 'Çıxan:',
                value: detail((BankAccount a) => money(a.totalOut)),
                pending: loading,
                style: body,
              ),
              rowGap,
              _Pair(
                label: 'Balans:',
                value: detail((BankAccount a) => money(a.balance)),
                pending: loading,
                style: body,
              ),
              rowGap,
              _Pair(
                label: 'Növ:',
                value: account.kindLabel ?? kUnknownValue,
                style: body,
              ),
              rowGap,
              _Pair(
                // `Komanda`'s design sets the status two spaces from its
                // label, and so does this one.
                label: 'Status: ',
                value: switch (active) {
                  true => 'aktiv',
                  false => 'deaktiv',
                  null => kUnknownValue,
                },
                color: switch (active) {
                  true => kSaleDone,
                  false => kSalePending,
                  null => null,
                },
                style: body,
              ),
              if (error != null && !loading) ...<Widget>[
                rowGap,
                _Failure(message: error, onRetry: onRetry, scale: s),
              ],
            ],
          ),
      ],
    );
  }

  /// [text] with 1C's doubled and trailing spaces made one, or null when
  /// that leaves nothing.
  static String? _given(String? text) {
    if (text == null) return null;
    final String tidy = tidySpaces(text);
    return tidy.isEmpty ? null : tidy;
  }
}

/// The room between two lines into which an opening card brings a label of
/// its own line — `Hesab adı:` over the name, `Hesab nömrəsi:` over the
/// number. The room grows from the [shut] gap to the [open] one, pushing
/// the value down, and the label comes in at its place [top] under the line
/// above.
///
/// The label is not a line of the column but drawn over the room: open, the
/// value stands closer under it than the label's own line is deep — CalSans
/// leaves a 22pt name a lot of air over its capitals — and a column cannot
/// overlap two lines.
class _LabelOver extends StatelessWidget {
  const _LabelOver({
    required this.label,
    required this.top,
    required this.shut,
    required this.open,
    required this.style,
    required this.t,
    required this.fade,
  });

  final String label;
  final double top;
  final double shut;
  final double open;
  final TextStyle style;
  final double t;
  final double fade;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: lerpDouble(shut, open, t),
      child: t == 0
          ? null
          // Cut at the room's foot while it opens, so the label is uncovered
          // as the line under it moves away and is never drawn over it;
          // open, nothing is cut — the label's line runs on into the air
          // over the name's capitals.
          : ClipRect(
              clipBehavior: t < 1 ? Clip.hardEdge : Clip.none,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned(
                    top: top,
                    left: 0,
                    right: 0,
                    child: Opacity(
                      opacity: fade,
                      child: _Line(text: label, style: style),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// A line whose label only an open card shows: `Bank:` ahead of the bank,
/// `Valyuta:` ahead of the currency. The label comes in from nothing as the
/// card opens, pushing the value along its line to where the open design
/// has it; shut, the value stands where the label will start.
class _LabelledLine extends StatelessWidget {
  const _LabelledLine({
    required this.label,
    required this.value,
    required this.style,
    required this.t,
    required this.fade,
  });

  final String label;
  final String value;
  final TextStyle style;
  final double t;
  final double fade;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        // Always laid out, even shut, so the line is as tall shut as open
        // and nothing jumps when the card starts to move.
        ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: t,
            child: Opacity(
              opacity: fade,
              child: Text(label, maxLines: 1, softWrap: false, style: style),
            ),
          ),
        ),
        Flexible(
          child: _Line(text: value, style: style),
        ),
      ],
    );
  }
}

/// One line of Poppins at the content's edge — a bank, a number — set
/// smaller rather than cut when it is too wide for its room: a number with
/// its tail missing is another account.
class _Line extends StatelessWidget {
  const _Line({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(text, maxLines: 1, softWrap: false, style: style),
      ),
    );
  }
}

/// `Balans: 0.00 ₼` — a heading and its value on one line, a space apart
/// as the design sets them.
class _Pair extends StatelessWidget {
  const _Pair({
    required this.label,
    required this.value,
    required this.style,
    this.color,
    this.pending = false,
  });

  final String label;
  final String value;
  final TextStyle style;

  /// The value's own colour — the status' green or red — or null for ink.
  final Color? color;

  /// The value is a stand-in while the account's own answer is on its way,
  /// and is drawn muted.
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final Color? color = pending ? kGlassInkMuted : this.color;
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text.rich(
          TextSpan(
            text: '$label ',
            children: <InlineSpan>[
              TextSpan(
                text: value,
                style: color == null ? null : style.copyWith(color: color),
              ),
            ],
          ),
          maxLines: 1,
          softWrap: false,
          style: style,
        ),
      ),
    );
  }
}

/// Why the account's own answer could not be read, and a way to ask again,
/// under the figures it left saying `—`.
class _Failure extends StatelessWidget {
  const _Failure({
    required this.message,
    required this.onRetry,
    required this.scale,
  });

  final String message;
  final VoidCallback onRetry;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            message,
            style: databaseCardStyle(
              11 * s,
              height: 1.55,
              color: kGlassInkMuted,
            ),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            foregroundColor: kGlassInk,
            visualDensity: VisualDensity.compact,
            textStyle: databaseCardStyle(11 * s, weight: FontWeight.w600),
          ),
          child: const Text('Yenidən cəhd et'),
        ),
      ],
    );
  }
}
