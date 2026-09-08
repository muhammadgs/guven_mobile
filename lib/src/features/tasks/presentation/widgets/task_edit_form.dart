import 'package:flutter/material.dart';

import '../../application/task_edit_controller.dart';
import '../../domain/task_dates.dart';
import '../../domain/task_edit.dart';
import '../new_task_metrics.dart';
import 'task_form_fields.dart';
import 'task_glass.dart';

/// The contents of the `Redaktə` sheet.
///
/// The design's order, top to bottom: who carries it out, what kind of work it
/// is, the description, the note, the deadline, whether the chosen company may
/// see it, the state to leave it in, and the two buttons. The title and the
/// back arrow scroll with the rest, the way the `Yeni tapşırıq` sheet's do.
///
/// Every row is one of the shared [TaskFormField] family, so this sheet and
/// the new-task sheet are the same form drawn twice rather than two forms that
/// look alike.
class TaskEditForm extends StatefulWidget {
  const TaskEditForm({
    super.key,
    required this.controller,
    required this.metrics,
    required this.openField,
    required this.dateOpen,
    required this.statusOpen,
    required this.onOpenField,
    required this.onOpenDate,
    required this.onOpenStatus,
    required this.onBack,
    required this.onCancel,
    required this.onSubmit,
  });

  final TaskEditController controller;
  final NewTaskMetrics metrics;

  /// The field whose panel is up, so its box can step aside under it.
  final TaskEditField? openField;
  final bool dateOpen;
  final bool statusOpen;

  final void Function(TaskEditField, Rect) onOpenField;
  final FieldTap onOpenDate;
  final FieldTap onOpenStatus;
  final VoidCallback onBack;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  State<TaskEditForm> createState() => _TaskEditFormState();
}

class _TaskEditFormState extends State<TaskEditForm> {
  final TextEditingController _description = TextEditingController();
  final TextEditingController _note = TextEditingController();

  /// The two text boxes are filled from the task's own row, which arrives a
  /// moment after the sheet opens — and exactly once, so a reply that lands
  /// while somebody is already typing cannot take the cursor off them.
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _seed();
    widget.controller.addListener(_seed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_seed);
    _description.dispose();
    _note.dispose();
    super.dispose();
  }

  void _seed() {
    if (_seeded || widget.controller.loading) return;
    _seeded = true;
    _description.text = widget.controller.description;
    _note.text = widget.controller.note;
  }

  @override
  Widget build(BuildContext context) {
    final NewTaskMetrics m = widget.metrics;
    final TaskEditController c = widget.controller;

    // Same reason as the new-task sheet's: Android's stretch overscroll lifts
    // the scrolled content into an `ImageFilterLayer`, and every box on this
    // form is a lens that would sample an empty backdrop inside one
    // ([backdrop-filter-black-flash]).
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
          TaskFormHeader(metrics: m, title: 'Redaktə', onBack: widget.onBack),
          SizedBox(height: m.betweenFields),
          for (final TaskEditField field in c.fields) ...<Widget>[
            TaskFormField(
              metrics: m,
              icon: field.icon,
              label: field.label,
              value: c.chosen(field)?.name,
              hint: c.listOf(field).notice ?? field.hint,
              busy: c.listOf(field).loading,
              active: widget.openField == field,
              onTap: (Rect rect) => widget.onOpenField(field, rect),
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
          TaskFormLabel(metrics: m, icon: kTaskEditNoteIcon, text: 'Qeyd'),
          SizedBox(height: m.fieldGap),
          TaskFormTextBox(
            metrics: m,
            controller: _note,
            hint: 'Bu tapşırıq haqqında qeyd yazın…',
            onChanged: c.setNote,
          ),
          SizedBox(height: m.betweenFields),
          TaskFormField(
            metrics: m,
            icon: 'assets/images/icons/new_task_icons/son_muddet.svg',
            label: 'Son müddət',
            value: c.dueDate == null ? null : formatTaskDate(c.dueDate!),
            hint: 'Tarix seçin',
            active: widget.dateOpen,
            onTap: widget.onOpenDate,
          ),
          if (c.showsVisibility) ...<Widget>[
            // The design sets this line apart from the fields either side of
            // it — it is the one row that is a switch rather than an answer.
            SizedBox(height: m.betweenFields * 1.6),
            TaskFormToggle(
              metrics: m,
              icon:
                  'assets/images/icons/new_task_icons/secilmis_sirkete_goster.svg',
              label: 'Seçilmiş şirkətə göstər',
              value: c.showToCompany,
              onChanged: c.setShowToCompany,
            ),
            SizedBox(height: m.betweenFields * 1.6),
          ] else
            SizedBox(height: m.betweenFields),
          TaskFormField(
            metrics: m,
            icon: kTaskEditStatusIcon,
            label: 'Status',
            // Deliberately blank until one of the three is picked: this field
            // asks where to *leave* the task, not where it is. Where it is, is
            // on the card.
            value: c.status?.label,
            hint: 'Status seçin',
            active: widget.statusOpen,
            onTap: widget.onOpenStatus,
          ),
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

/// `İmtina` and `Yadda saxla`, or — while the change is being written — what
/// is being written.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.metrics,
    required this.controller,
    required this.onCancel,
    required this.onSubmit,
  });

  final NewTaskMetrics metrics;
  final TaskEditController controller;
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
                  label: 'İmtina',
                  icon: Icons.close_rounded,
                  gradient: kNewTaskCancelGradient,
                  onTap: onCancel,
                ),
              ),
              SizedBox(width: 12 * metrics.scale),
              Flexible(
                child: TaskFormButton(
                  metrics: metrics,
                  label: 'Yadda saxla',
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
