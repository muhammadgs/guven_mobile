import 'package:flutter/material.dart';

import '../../application/new_task_controller.dart';
import '../../domain/new_task.dart';
import '../../domain/task_attachment.dart';
import '../../domain/task_dates.dart';
import '../new_task_metrics.dart';
import 'new_task_box.dart';
import 'task_form_fields.dart';
import 'task_glass.dart';
import 'voice_recorder_field.dart';

/// The contents of the `Yeni tapşırıq` sheet.
///
/// One scroll view, in the design's order: the company and the people, the
/// work type and the department, the deadline, whether the customer may see
/// it, the description, the recording, the files, and then the two buttons.
/// The title and the back arrow scroll with the rest, exactly as the design
/// draws them — the second screen of it shows neither.
///
/// The rows themselves are [TaskFormField] and friends, which `Redaktə` is
/// built out of too. Nothing here decides where anything sits on screen: the
/// sheet's rect comes from [NewTaskMetrics] and this fills it.
class NewTaskForm extends StatefulWidget {
  const NewTaskForm({
    super.key,
    required this.controller,
    required this.metrics,
    required this.kind,
    required this.openField,
    required this.dateOpen,
    required this.onOpenField,
    required this.onOpenDate,
    required this.onBack,
    required this.onCancel,
    required this.onSubmit,
  });

  final NewTaskController controller;
  final NewTaskMetrics metrics;
  final NewTaskKind kind;

  /// The field whose panel is up, so its box can stay lit under it.
  final NewTaskField? openField;
  final bool dateOpen;

  final void Function(NewTaskField, Rect) onOpenField;
  final FieldTap onOpenDate;
  final VoidCallback onBack;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  State<NewTaskForm> createState() => _NewTaskFormState();
}

class _NewTaskFormState extends State<NewTaskForm> {
  late final TextEditingController _description = TextEditingController(
    text: widget.controller.description,
  );

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final NewTaskMetrics m = widget.metrics;
    final NewTaskController c = widget.controller;

    // Android's stretch overscroll lifts the scrolled content into an
    // `ImageFilterLayer`, and every box on this form is a lens: inside that
    // layer they sample an empty backdrop instead of the sheet and vanish the
    // moment a finger pulls past either end
    // ([backdrop-filter-black-flash]) — the home screen's activity tray drops
    // the stretch for exactly this reason. The physics here are clamping, so
    // the only thing that goes with it is the artefact.
    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(overscroll: false),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          m.sheetPadH,
          m.sheetPadTop,
          m.sheetPadH,
          m.sheetPadBottom,
        ),
        physics: const ClampingScrollPhysics(),
        children: <Widget>[
          TaskFormHeader(
            metrics: m,
            title: widget.kind.sheetTitle,
            onBack: widget.onBack,
          ),
          SizedBox(height: m.betweenFields),
          for (final NewTaskField field in c.fields) ...<Widget>[
            TaskFormField(
              metrics: m,
              icon: field.icon,
              label: field.labelFor(widget.kind),
              value: c.chosen(field)?.name,
              // A field whose list is deliberately not offered says why in
              // place of its hint, so the reason is on the form rather than
              // hidden behind a tap.
              hint: c.listOf(field).notice ?? field.hintFor(widget.kind),
              busy: c.listOf(field).loading,
              active: widget.openField == field,
              onTap: (Rect rect) => widget.onOpenField(field, rect),
            ),
            SizedBox(height: m.betweenFields),
          ],
          TaskFormField(
            metrics: m,
            icon: 'assets/images/icons/new_task_icons/son_muddet.svg',
            label: 'Son müddət',
            value: c.dueDate == null ? null : formatTaskDate(c.dueDate!),
            hint: 'Tarix seçin',
            active: widget.dateOpen,
            onTap: widget.onOpenDate,
          ),
          SizedBox(height: m.betweenFields),
          if (widget.kind.hasVisibilityToggle) ...<Widget>[
            TaskFormToggle(
              metrics: m,
              icon:
                  'assets/images/icons/new_task_icons/secilmis_sirkete_goster.svg',
              label: 'Seçilmiş şirkətə göstər',
              value: c.showToCompany,
              onChanged: c.setShowToCompany,
            ),
            SizedBox(height: m.betweenFields),
          ],
          TaskFormLabel(
            metrics: m,
            icon: 'assets/images/icons/new_task_icons/aciqlama.svg',
            text: 'Tapşırıq açıqlaması',
          ),
          SizedBox(height: m.fieldGap),
          TaskFormTextBox(
            metrics: m,
            controller: _description,
            hint: 'Tapşırığın detallı təsvirini yazın…',
            onChanged: c.setDescription,
          ),
          SizedBox(height: m.betweenFields),
          TaskFormLabel(
            metrics: m,
            icon: 'assets/images/icons/new_task_icons/ses_qeydi.svg',
            text: 'Səs qeydi',
          ),
          SizedBox(height: m.fieldGap),
          VoiceRecorderField(recorder: c.voice, scale: m.scale),
          SizedBox(height: m.betweenFields),
          TaskFormLabel(
            metrics: m,
            icon: 'assets/images/icons/new_task_icons/fayl.svg',
            text: 'Fayllar',
          ),
          SizedBox(height: m.fieldGap),
          _Files(metrics: m, controller: c),
          SizedBox(height: m.betweenFields * 1.4),
          _Footer(
            metrics: m,
            controller: c,
            onCancel: widget.onCancel,
            onSubmit: widget.onSubmit,
          ),
        ],
      ),
    );
  }
}

/// The `+` that opens the phone's picker, and what has been picked so far.
class _Files extends StatelessWidget {
  const _Files({required this.metrics, required this.controller});

  final NewTaskMetrics metrics;
  final NewTaskController controller;

  @override
  Widget build(BuildContext context) {
    final double box = 46 * metrics.scale;

    return Wrap(
      spacing: 8 * metrics.scale,
      runSpacing: 8 * metrics.scale,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Semantics(
          button: true,
          label: 'Fayl əlavə et',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: controller.addFiles,
            child: NewTaskBox(
              radius: box / 2,
              child: SizedBox.square(
                dimension: box,
                child: Icon(
                  Icons.add_rounded,
                  size: box * 0.5,
                  color: kNewTaskValueInk,
                ),
              ),
            ),
          ),
        ),
        for (final PendingUpload file in controller.files)
          _FileChip(
            metrics: metrics,
            file: file,
            onRemove: () => controller.removeFile(file),
          ),
      ],
    );
  }
}

/// One picked file: its type, and a way to take it off again.
///
/// Labelled with the *type* — `PDF faylı` — like every other file chip in this
/// app and on the site, with the real filename underneath so two attachments
/// of the same type are still telling apart before they are sent.
class _FileChip extends StatelessWidget {
  const _FileChip({
    required this.metrics,
    required this.file,
    required this.onRemove,
  });

  final NewTaskMetrics metrics;
  final PendingUpload file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AttachmentKind kind = AttachmentKind.resolve(
      mimeType: file.mimeType,
      filename: file.name,
      isVoiceNote: file.isVoiceNote,
    );
    final double glyph = 18 * metrics.scale;

    return Container(
      constraints: BoxConstraints(maxWidth: metrics.sheet.width * 0.72),
      padding: EdgeInsets.fromLTRB(
        10 * metrics.scale,
        7 * metrics.scale,
        6 * metrics.scale,
        7 * metrics.scale,
      ),
      decoration: ShapeDecoration(
        color: const Color(0xB8FFFFFF),
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(14 * metrics.scale),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(kind.icon, size: glyph, color: kind.color),
          SizedBox(width: 8 * metrics.scale),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  kind.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5 * metrics.scale,
                    height: 1.15,
                    color: kGlassInk,
                  ),
                ),
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10.5 * metrics.scale,
                    height: 1.2,
                    color: kNewTaskHintInk,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 4 * metrics.scale),
          Semantics(
            button: true,
            label: 'Faylı çıxar',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRemove,
              child: Padding(
                padding: EdgeInsets.all(4 * metrics.scale),
                child: Icon(
                  Icons.close_rounded,
                  size: glyph * 0.85,
                  color: kNewTaskHintInk,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `Ləğv edin` and `Əlavə edin`, or — while the task is being sent — what is
/// being sent.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.metrics,
    required this.controller,
    required this.onCancel,
    required this.onSubmit,
  });

  final NewTaskMetrics metrics;
  final NewTaskController controller;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final String? progress = controller.progress;
    final String? failure = controller.failure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (failure != null) ...<Widget>[
          Text(
            failure,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13 * metrics.scale,
              height: 1.3,
              color: const Color(0xFFC2410C),
            ),
          ),
          SizedBox(height: 10 * metrics.scale),
        ],
        if (progress != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox.square(
                dimension: 16 * metrics.scale,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kGlassInkMuted,
                ),
              ),
              SizedBox(width: 10 * metrics.scale),
              Text(
                progress,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.5 * metrics.scale,
                  height: 1.3,
                  color: kGlassInkMuted,
                ),
              ),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Flexible(
                child: TaskFormButton(
                  metrics: metrics,
                  label: 'Ləğv edin',
                  icon: Icons.close_rounded,
                  gradient: kNewTaskCancelGradient,
                  onTap: onCancel,
                ),
              ),
              SizedBox(width: 12 * metrics.scale),
              Flexible(
                child: TaskFormButton(
                  metrics: metrics,
                  label: 'Əlavə edin',
                  icon: Icons.check_rounded,
                  gradient: kNewTaskSubmitGradient,
                  onTap: onSubmit,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
