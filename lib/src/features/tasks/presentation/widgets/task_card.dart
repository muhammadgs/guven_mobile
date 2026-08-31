import 'dart:math' as math;
import 'dart:ui' as ui show ImageFilter;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../../shared/layout.dart';
import '../../application/task_voice_player.dart';
import '../../domain/task_attachment.dart';
import '../../domain/task_dates.dart';
import '../../domain/task_item.dart';
import '../../domain/task_status.dart';
import 'task_actions.dart';
import 'task_card_layout.dart';
import 'task_glass.dart';
import 'task_voice_note.dart';

/// One task, shut or open.
///
/// Not glass: the design asks for a flat mint fill over a plain background
/// blur, and it is the right call — a list of a dozen live lenses would be
/// both slower and busier than the two markers this screen already has. The
/// blur is grouped with the rest of the list's ([BackdropGroup]) so all of
/// them are sampled once per frame rather than once per card.
///
/// Tapping anywhere that is not a button opens it. What happens then is
/// [TaskCardLayout]'s: the card does not swap one arrangement for another, it
/// travels between them.
class TaskCard extends StatefulWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.mine,
    required this.busy,
    required this.attachments,
    required this.openingFileIds,
    required this.voice,
    required this.onAction,
    required this.onOpenFile,
    required this.onOpened,
  });

  final TaskItem task;

  /// Whether the signed-in user is the executor. Their name is set in bold and
  /// they get the buttons; everybody else gets the status chip.
  final bool mine;

  /// True while one of this card's verbs is in flight.
  final bool busy;

  /// The task's files, or null while they have not been described yet.
  final List<TaskAttachment>? attachments;

  /// Which of them are being downloaded right now.
  final Set<String> openingFileIds;

  /// The screen's one voice-note player. Listened to *inside* the recordings
  /// section rather than around the card, so a note playing does not rebuild
  /// every card in the list ten times a second.
  final TaskVoicePlayer voice;

  final ValueChanged<TaskAction> onAction;

  /// Download this file and hand it to the phone.
  final ValueChanged<TaskAttachment> onOpenFile;

  /// Fired the first time the card is opened, so the screen can go and fetch
  /// the files this card is about to show.
  final VoidCallback onOpened;

  @override
  State<TaskCard> createState() => _TaskCardState();
}

/// How many lines of the description a shut card shows before the ellipsis.
const int _kShutDescriptionLines = 4;

class _TaskCardState extends State<TaskCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 360),
  );

  late final Animation<double> _open = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInOutCubic,
  );

  bool _everOpened = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_controller.status == AnimationStatus.forward ||
        _controller.status == AnimationStatus.completed) {
      _controller.reverse();
      return;
    }
    _controller.forward();
    if (!_everOpened) {
      _everOpened = true;
      widget.onOpened();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double radius = scaled(context, kTaskCardRadius);
    final double padding = scaled(context, 18);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: kTaskCardLift,
        ),
        child: ClipRSuperellipse(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter.grouped(
            filter: ui.ImageFilter.blur(
              sigmaX: kTaskCardBlurSigma,
              sigmaY: kTaskCardBlurSigma,
            ),
            child: ColoredBox(
              color: kTaskCardFill,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  padding,
                  padding,
                  padding,
                  padding * 0.55,
                ),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double width = constraints.maxWidth;
                    final double s = uiScale(context);
                    final TaskCardMetrics metrics = _metrics(s);
                    // Neither of these depends on the animation, so they are
                    // worked out once here rather than on every frame of it.
                    final _NameFit fit = _NameFit.measure(
                      context: context,
                      task: widget.task,
                      mine: widget.mine,
                      width: width,
                      scale: s,
                      metrics: metrics,
                    );

                    return AnimatedBuilder(
                      animation: _open,
                      builder: (BuildContext context, _) =>
                          _body(width, s, metrics, fit, _open.value),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The card's proportions, taken off the design: the shut card gives a
  /// little over half its width to the people and the buttons and the rest to
  /// the description, with the two columns almost touching and only a narrow
  /// lane on the left for the bullets.
  TaskCardMetrics _metrics(double s) => TaskCardMetrics(
    headerGap: 14 * s,
    nameGap: 12 * s,
    actionsGap: 11 * s,
    columnGap: 8 * s,
    leftFraction: 0.52,
    stackGap: 16 * s,
    dotRadius: 3.2 * s,
    dotLane: 12 * s,
    connectorSpan: 48 * s,
    chevronGap: 6 * s,
  );

  Widget _body(
    double width,
    double s,
    TaskCardMetrics metrics,
    _NameFit fit,
    double t,
  ) {
    final TaskItem task = widget.task;
    final double shutDescriptionWidth = math.max(
      width - width * metrics.leftFraction - metrics.columnGap,
      40,
    );

    return TaskCardLayout(
      expansion: t,
      metrics: metrics,
      connectorColor: kGlassInk,
      slots: <TaskCardSlot, Widget>{
        TaskCardSlot.stamp: _Stamp(at: task.createdAt, t: t, scale: s),
        TaskCardSlot.title: _Headline(
          text: task.company,
          fontSize: lerpDouble(20, 23, t)! * s,
          letterSpacing: -0.4 * s,
        ),
        TaskCardSlot.subtitle: _Headline(
          text: task.workType,
          fontSize: lerpDouble(15, 17, t)! * s,
          letterSpacing: -0.2 * s,
        ),
        TaskCardSlot.fromName: _PersonName(
          name: task.assignedBy ?? '—',
          fontSize: fit.sizeAt(t),
          bold: false,
        ),
        TaskCardSlot.toName: _PersonName(
          name: task.assignedTo ?? '—',
          fontSize: fit.sizeAt(t),
          // The one signal that a task is the reader's own, straight from the
          // design: their name, and only theirs, is set in bold.
          bold: widget.mine,
        ),
        TaskCardSlot.description: _Description(
          text: task.description ?? '',
          t: t,
          shutWidth: shutDescriptionWidth,
          openWidth: width,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: lerpDouble(13, 14, t)! * s,
            height: 1.42,
            color: kTaskBodyInk,
          ),
        ),
        TaskCardSlot.actions: _Actions(
          task: task,
          mine: widget.mine,
          busy: widget.busy,
          onAction: widget.onAction,
          t: t,
          scale: s,
        ),
        TaskCardSlot.extras: _Extras(
          dueDate: task.dueDate,
          attachments: widget.attachments,
          expectsAttachments: task.hasAttachments,
          openingIds: widget.openingFileIds,
          onOpenFile: widget.onOpenFile,
          voice: widget.voice,
          t: t,
          scale: s,
        ),
        TaskCardSlot.chevron: _Chevron(t: t, scale: s, onTap: _toggle),
      },
    );
  }
}

/// What size the two names are set at, shut and open.
///
/// Azerbaijani full names are long — `Məhəmməd Qasımov` is sixteen characters
/// — and the open card asks for two of them side by side with an arrow
/// between. On a 390pt phone that does not fit at the size the design draws,
/// and the only two ways out are to cut a name short or to set it smaller. A
/// person's name is the one thing on this card that must not be cut, so the
/// pair is measured against the room it actually has and both names take the
/// smaller of the two scales — both, so they never end up at different sizes
/// on the same line.
@immutable
class _NameFit {
  const _NameFit({required this.shutSize, required this.openSize});

  /// The base sizes from the design, before any fitting.
  static const double _shutBase = 13.5;
  static const double _openBase = 14.5;

  /// How far a name may be scaled down before it is allowed to ellipsise
  /// instead. Below this it stops being readable and a cut name is the lesser
  /// evil.
  static const double _floor = 0.74;

  /// Scaling a font by exactly the ratio it is over by lands the text on the
  /// boundary, where rounding decides whether it ellipsises. This keeps it a
  /// hair inside.
  static const double _safety = 0.97;

  final double shutSize;
  final double openSize;

  double sizeAt(double t) => lerpDouble(shutSize, openSize, t)!;

  static _NameFit measure({
    required BuildContext context,
    required TaskItem task,
    required bool mine,
    required double width,
    required double scale,
    required TaskCardMetrics metrics,
  }) {
    final TextDirection direction = Directionality.of(context);
    final TextScaler scaler = MediaQuery.textScalerOf(context);

    double natural(String? text, double size, bool bold) {
      if (text == null || text.isEmpty) return 0;
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            fontSize: size,
            height: 1.25,
          ),
        ),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      return painter.width;
    }

    double fit(double available, double required, double size) {
      if (required <= 0 || available <= 0) return size;
      return size * (available * _safety / required).clamp(_floor, 1.0);
    }

    // Stacked, each name has the left column less the bullet lane, so the
    // longer of the two sets the size. Side by side they share one line, so
    // what matters is the pair's *total* — a short name beside a long one
    // leaves the long one more room, rather than both being held to half.
    final double shutRoom = width * metrics.leftFraction - metrics.dotLane;
    final double openRoom = width - metrics.connectorSpan;

    final double shutBase = _shutBase * scale;
    final double openBase = _openBase * scale;

    return _NameFit(
      shutSize: fit(
        shutRoom,
        math.max(
          natural(task.assignedBy, shutBase, false),
          natural(task.assignedTo, shutBase, mine),
        ),
        shutBase,
      ),
      openSize: fit(
        openRoom,
        natural(task.assignedBy, openBase, false) +
            natural(task.assignedTo, openBase, mine),
        openBase,
      ),
    );
  }
}

/// `2026-08-25   18:15`, in italics, as one line.
class _Stamp extends StatelessWidget {
  const _Stamp({required this.at, required this.t, required this.scale});

  final DateTime? at;
  final double t;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final DateTime? at = this.at;
    if (at == null) return const SizedBox.shrink();

    final TextStyle style = TextStyle(
      fontFamily: 'Poppins',
      fontStyle: FontStyle.italic,
      fontSize: lerpDouble(12.5, 13.5, t)! * scale,
      height: 1.2,
      color: kGlassInk,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(formatTaskDate(at), style: style),
        SizedBox(width: lerpDouble(14, 22, t)! * scale),
        Text(formatTaskTime(at), style: style),
      ],
    );
  }
}

/// The company name and the work type: the card's two display lines.
class _Headline extends StatelessWidget {
  const _Headline({
    required this.text,
    required this.fontSize,
    required this.letterSpacing,
  });

  final String text;
  final double fontSize;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        // CalSans, as the design specifies for both lines — the only two on
        // this screen that are not Poppins.
        fontFamily: 'CalSans',
        fontSize: fontSize,
        height: 1.16,
        letterSpacing: letterSpacing,
        color: kGlassInk,
      ),
    );
  }
}

class _PersonName extends StatelessWidget {
  const _PersonName({
    required this.name,
    required this.fontSize,
    required this.bold,
  });

  final String name;
  final double fontSize;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        fontSize: fontSize,
        height: 1.25,
        color: kGlassInk,
      ),
    );
  }
}

/// The description, growing from a four-line excerpt to the whole thing.
///
/// Both versions are drawn on top of each other and the ellipsised one is
/// faded out as the card opens. They agree line for line until the excerpt's
/// last one, so the only thing the fade is actually hiding is the `…`.
class _Description extends StatelessWidget {
  const _Description({
    required this.text,
    required this.t,
    required this.shutWidth,
    required this.openWidth,
    required this.style,
  });

  final String text;
  final double t;
  final double shutWidth;
  final double openWidth;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextDirection direction = Directionality.of(context);

    double heightAt(double width, int? maxLines) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: maxLines,
        ellipsis: maxLines == null ? null : '…',
      )..layout(maxWidth: math.max(width, 1));
      return painter.height;
    }

    // Measured at the two *end* widths rather than at the width of this frame,
    // so the card's height slides between two fixed numbers instead of jumping
    // every time the reflowing text gains or loses a line mid-animation.
    final double height = lerpDouble(
      heightAt(shutWidth, _kShutDescriptionLines),
      heightAt(openWidth, null),
      t,
    )!;

    return ClipRect(
      child: SizedBox(
        height: height,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minHeight: 0,
          maxHeight: double.infinity,
          child: Stack(
            children: <Widget>[
              Text(text, style: style),
              if (t < 0.999)
                Opacity(
                  opacity: 1 - t,
                  child: Text(
                    text,
                    maxLines: _kShutDescriptionLines,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The gradient buttons, or the status chip when there is nothing to press.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.task,
    required this.mine,
    required this.busy,
    required this.onAction,
    required this.t,
    required this.scale,
  });

  final TaskItem task;
  final bool mine;
  final bool busy;
  final ValueChanged<TaskAction> onAction;
  final double t;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final double height = lerpDouble(32, 42, t)! * scale;
    final double fontSize = lerpDouble(13, 16, t)! * scale;
    final double padding = lerpDouble(16, 26, t)! * scale;

    final List<TaskAction> actions = task.source.isActionable
        ? actionsFor(task.status, mine: mine)
        : const <TaskAction>[];

    final Widget content = actions.isEmpty
        ? TaskStatusChip(
            status: task.status,
            height: height,
            fontSize: fontSize,
            padding: padding,
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < actions.length; i++) ...<Widget>[
                if (i > 0) SizedBox(width: lerpDouble(9, 15, t)! * scale),
                TaskActionButton(
                  action: actions[i],
                  height: height,
                  fontSize: fontSize,
                  padding: padding,
                  busy: busy,
                  onTap: () => onAction(actions[i]),
                ),
              ],
            ],
          );

    // A shut card's left column can be narrower than two buttons need on a
    // small phone. Scaling the pair down by a few percent keeps both labels
    // whole, which an ellipsis inside `Təsdiq et` would not.
    return FittedBox(fit: BoxFit.scaleDown, child: content);
  }
}

/// Files and the deadline: the columns of the site's table that only an opened
/// card has room for.
class _Extras extends StatelessWidget {
  const _Extras({
    required this.dueDate,
    required this.attachments,
    required this.expectsAttachments,
    required this.openingIds,
    required this.onOpenFile,
    required this.voice,
    required this.t,
    required this.scale,
  });

  final DateTime? dueDate;
  final List<TaskAttachment>? attachments;
  final TaskVoicePlayer voice;

  /// Whether the task row named any files at all. Drives the small spinner
  /// while they are being described, so the section does not pop in late.
  final bool expectsAttachments;

  /// Ids of the files currently being downloaded.
  final Set<String> openingIds;

  final ValueChanged<TaskAttachment> onOpenFile;

  final double t;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final List<TaskAttachment> all = attachments ?? const <TaskAttachment>[];
    // Recordings get a section of their own, because they are not opened —
    // they are listened to, in place. Everything else stays a chip.
    final List<TaskAttachment> notes = <TaskAttachment>[
      for (final TaskAttachment file in all)
        if (file.kind == AttachmentKind.voiceNote) file,
    ];
    final List<TaskAttachment> files = <TaskAttachment>[
      for (final TaskAttachment file in all)
        if (file.kind != AttachmentKind.voiceNote) file,
    ];
    final bool loading = attachments == null && expectsAttachments;
    final bool hasFiles = files.isNotEmpty || loading;
    final bool hasNotes = notes.isNotEmpty;
    if (!hasFiles && !hasNotes && dueDate == null) {
      return const SizedBox.shrink();
    }

    final TextStyle label = TextStyle(
      fontFamily: 'Poppins',
      fontSize: 13.5 * scale,
      height: 1.3,
      color: kTaskBodyInk,
    );

    // Held back until the card is most of the way open: these sections have no
    // shut-card counterpart to travel from, so they arrive rather than move.
    final double fade = ((t - 0.45) / 0.5).clamp(0.0, 1.0);

    // Laid out even while it is invisible: the card's open height is measured
    // from it on every frame, and a section that only gained its height at the
    // moment it faded in would put a step in the middle of the animation. It
    // is kept out of the semantics tree instead, so a screen reader is not
    // offered a deadline the card is not showing.
    return ExcludeSemantics(
      excluding: fade <= 0,
      child: Opacity(
        opacity: fade,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (hasNotes) ...<Widget>[
              Text('Səs qeydləri:', style: label),
              SizedBox(height: 8 * scale),
              ListenableBuilder(
                listenable: voice,
                builder: (BuildContext context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (int i = 0; i < notes.length; i++) ...<Widget>[
                      if (i > 0) SizedBox(height: 8 * scale),
                      TaskVoiceNote(
                        file: notes[i],
                        player: voice,
                        scale: scale,
                        saving: openingIds.contains(notes[i].id),
                        onSave: () => onOpenFile(notes[i]),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 14 * scale),
            ],
            if (hasFiles) ...<Widget>[
              Text('Fayllar:', style: label),
              SizedBox(height: 8 * scale),
              if (loading)
                SizedBox(
                  height: 18 * scale,
                  width: 18 * scale,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kGlassInkMuted,
                  ),
                )
              else
                Wrap(
                  spacing: 8 * scale,
                  runSpacing: 8 * scale,
                  children: <Widget>[
                    for (final TaskAttachment file in files)
                      _AttachmentChip(
                        file: file,
                        scale: scale,
                        opening: openingIds.contains(file.id),
                        onTap: () => onOpenFile(file),
                      ),
                  ],
                ),
              SizedBox(height: 14 * scale),
            ],
            if (dueDate != null) ...<Widget>[
              Text('Son müddət:', style: label),
              SizedBox(height: 3 * scale),
              Text(
                formatTaskDate(dueDate!),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontStyle: FontStyle.italic,
                  fontSize: 14 * scale,
                  height: 1.3,
                  color: kGlassInk,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One attached file: its type badge and the type's name.
///
/// The label is the *type* — `PDF faylı`, `EXCEL faylı` — not the filename,
/// which is what the design draws and what the website's own chips say. The
/// real filename is the accessibility label and the name the file is saved
/// under when it is opened.
///
/// Tapping downloads it and hands it to the phone. While that is happening the
/// type icon is replaced by a spinner in the same place, so the chip does not
/// change size.
class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({
    required this.file,
    required this.scale,
    required this.opening,
    required this.onTap,
  });

  final TaskAttachment file;
  final double scale;
  final bool opening;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double glyph = 18 * scale;

    return Semantics(
      button: true,
      label: file.name ?? file.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: opening ? null : onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            10 * scale,
            7 * scale,
            14 * scale,
            7 * scale,
          ),
          decoration: ShapeDecoration(
            color: const Color(0xF2FFFFFF),
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(12 * scale),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox.square(
                dimension: glyph,
                child: opening
                    ? Padding(
                        padding: EdgeInsets.all(1.5 * scale),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: file.kind.color,
                        ),
                      )
                    : Icon(file.kind.icon, size: glyph, color: file.kind.color),
              ),
              SizedBox(width: 8 * scale),
              Text(
                file.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13 * scale,
                  height: 1.2,
                  color: kGlassInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The open/close hint at the card's bottom edge.
class _Chevron extends StatelessWidget {
  const _Chevron({required this.t, required this.scale, required this.onTap});

  final double t;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 22 * scale),
        child: Transform.rotate(
          angle: math.pi * t,
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 22 * scale,
            color: kGlassInkMuted,
          ),
        ),
      ),
    );
  }
}
