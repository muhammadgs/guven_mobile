import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../data/task_create_api.dart';
import '../data/task_edit_api.dart';
import '../domain/new_task.dart';
import '../domain/task_edit.dart';
import '../domain/task_item.dart';
import '../domain/task_status.dart';
import 'new_task_controller.dart' show OptionList;

/// How a save ended.
///
/// [status] is the state the task is in afterwards, or null when the sheet
/// changed fields but not the task's state — the card takes it straight away
/// so the chip swaps at the speed of the tap rather than of the round trip.
@immutable
class TaskEditOutcome {
  const TaskEditOutcome({required this.saved, this.status, this.message});

  final bool saved;
  final TaskStatus? status;
  final String? message;
}

/// Drives `Redaktə`: the task's current answers, the two lists it offers, and
/// the one or two calls it takes to write a change back.
///
/// Seeded from three places, in this order. The card's own [TaskItem] fills
/// the boxes on the very first frame, so the sheet is never blank while it
/// flies open. `GET /tasks/{id}` then supplies the three things no list row
/// carries — `notes`, `work_type_id`, `is_company_viewable`. The pickers'
/// lists arrive last and only reconcile *which row is ticked*; they never
/// change an answer.
class TaskEditController extends ChangeNotifier {
  TaskEditController(
    this._session,
    this.task, {
    TaskEditApi? api,
    TaskCreateApi? options,
  }) : _api = api ?? TaskEditApi(_session.client),
       _options = options ?? TaskCreateApi(_session.client) {
    _seedFromCard();
    unawaited(_loadSnapshot());
    unawaited(_loadLists());
  }

  final SessionController _session;
  final TaskEditApi _api;
  final TaskCreateApi _options;

  /// The card this sheet was opened from.
  final TaskItem task;

  final Map<TaskEditField, OptionList> _lists = <TaskEditField, OptionList>{
    for (final TaskEditField field in TaskEditField.values)
      field: const OptionList(),
  };

  final Map<TaskEditField, TaskOption> _chosen = <TaskEditField, TaskOption>{};

  /// What the task looked like when the sheet opened. Everything sent is
  /// diffed against this, so an untouched row is never written.
  Map<TaskEditField, TaskOption> _original = <TaskEditField, TaskOption>{};
  String _originalDescription = '';
  String _originalNote = '';
  DateTime? _originalDueDate;
  bool _originalShowToCompany = true;

  String _description = '';
  String _note = '';
  DateTime? _dueDate;
  bool _showToCompany = true;
  TaskEditStatus? _status;

  /// True until `GET /tasks/{id}` has answered. The two text boxes are built
  /// from the controller's text once it has, which is why the form waits for
  /// this before it hands them their initial value.
  bool _loading = true;
  bool get loading => _loading;

  String? _progress;
  String? get progress => _progress;
  bool get busy => _progress != null;

  String? _failure;
  String? get failure => _failure;

  bool _disposed = false;

  OptionList listOf(TaskEditField field) => _lists[field]!;
  TaskOption? chosen(TaskEditField field) => _chosen[field];

  String get description => _description;
  String get note => _note;
  DateTime? get dueDate => _dueDate;
  bool get showToCompany => _showToCompany;
  TaskEditStatus? get status => _status;

  /// The rows this task's resource can actually store — see
  /// [TaskEditCapabilities].
  List<TaskEditField> get fields => <TaskEditField>[
    TaskEditField.executor,
    if (task.source.canEditWorkType) TaskEditField.workType,
  ];

  bool get showsVisibility => task.source.canEditVisibility;

  /// Whether anything on the sheet differs from what was opened.
  bool get isDirty =>
      _status != null ||
      _description.trim() != _originalDescription ||
      _note.trim() != _originalNote ||
      _dueDate != _originalDueDate ||
      (showsVisibility && _showToCompany != _originalShowToCompany) ||
      TaskEditField.values.any(
        (TaskEditField field) => _chosen[field]?.id != _original[field]?.id,
      );

  // ── Seeding ─────────────────────────────────────────────────────────────

  /// What the card already knows, so the sheet opens filled rather than empty.
  void _seedFromCard() {
    if (task.assignedTo != null) {
      _chosen[TaskEditField.executor] = TaskOption(
        id: task.assignedToId ?? -1,
        name: task.assignedTo!,
      );
    }
    if (task.workTypeId != null || task.workType != '—') {
      _chosen[TaskEditField.workType] = TaskOption(
        id: task.workTypeId ?? -1,
        name: task.workType,
      );
    }
    _description = task.description ?? '';
    _dueDate = task.dueDate;
    _original = Map<TaskEditField, TaskOption>.of(_chosen);
    _originalDescription = _description.trim();
    _originalDueDate = _dueDate;
  }

  /// The three answers only the task's own row carries.
  Future<void> _loadSnapshot() async {
    try {
      final TaskEditSnapshot row = await _api.load(task);

      final String? executor = row.assignedToName ?? task.assignedTo;
      if (row.assignedToId != null && executor != null) {
        _chosen[TaskEditField.executor] = TaskOption(
          id: row.assignedToId!,
          name: executor,
        );
      }
      final String? work =
          row.workTypeName ?? _chosen[TaskEditField.workType]?.name;
      if (row.workTypeId != null && work != null) {
        _chosen[TaskEditField.workType] = TaskOption(
          id: row.workTypeId!,
          name: work,
        );
      }
      _description = row.description ?? _description;
      _note = row.note ?? '';
      _dueDate = row.dueDate ?? _dueDate;
      _showToCompany = row.showToCompany ?? _showToCompany;
    } on ApiException catch (error) {
      // Not fatal: the card's own row filled most of the form already, and a
      // sheet that refuses to open over one missing note helps nobody. The
      // failure is said once, above the buttons.
      _failure = error.message;
    }

    _original = Map<TaskEditField, TaskOption>.of(_chosen);
    _originalDescription = _description.trim();
    _originalNote = _note.trim();
    _originalDueDate = _dueDate;
    _originalShowToCompany = _showToCompany;
    _loading = false;

    // A list that arrived while this request was in flight has already been
    // reconciled against the *seeded* answer, which this has just replaced —
    // so it is matched up again rather than left with nothing ticked.
    for (final TaskEditField field in TaskEditField.values) {
      _reconcile(field, listOf(field).options);
    }
    _notify();
  }

  Future<void> _loadLists() async {
    unawaited(_load(TaskEditField.executor, _employees));
    if (task.source.canEditWorkType) {
      unawaited(_load(TaskEditField.workType, _workTypes));
    }
  }

  /// The people who could carry this task out.
  ///
  /// *Whose* people depends on the task. An internal task is carried out by
  /// one of ours; a cross-company one by somebody at the executor company we
  /// handed it up to; a partner one by somebody at the partner. The card knows
  /// that company only by name, so it is matched back to a code through the
  /// same two lists the `Yeni tapşırıq` sheet offers — and where no match
  /// comes back the field says so rather than listing the wrong people.
  Future<List<TaskOption>> _employees() async {
    final String? mine = _companyCode;
    if (mine == null) return const <TaskOption>[];
    if (task.source == TaskSource.internal) return _options.employees(mine);

    final List<TaskOption> companies = task.source == TaskSource.partner
        ? await _options.partners(mine)
        : await _options.parentCompanies(mine);
    final String? code = _codeNamed(task.company, companies);
    if (code == null) throw const ApiException('Şirkətin işçiləri tapılmadı.');
    return _options.employees(code);
  }

  Future<List<TaskOption>> _workTypes() {
    final int? id = _myCompanyId;
    if (id == null) return Future<List<TaskOption>>.value(const <TaskOption>[]);
    return _options.workTypes(id);
  }

  /// The company code behind a company *name*, or null when none of them is
  /// called that.
  static String? _codeNamed(String name, List<TaskOption> companies) {
    final String wanted = name.trim().toLowerCase();
    for (final TaskOption company in companies) {
      if (company.name.trim().toLowerCase() == wanted) return company.code;
    }
    return null;
  }

  // ── Answering ───────────────────────────────────────────────────────────

  void choose(TaskEditField field, TaskOption option) {
    _chosen[field] = option;
    _failure = null;
    _notify();
  }

  void setDueDate(DateTime day) {
    _dueDate = day;
    _failure = null;
    _notify();
  }

  /// Typed into, so deliberately *not* a notification: rebuilding the sheet on
  /// every keystroke would fight the field's own cursor.
  void setDescription(String text) {
    _description = text;
    _failure = null;
  }

  void setNote(String text) {
    _note = text;
    _failure = null;
  }

  void setShowToCompany(bool value) {
    _showToCompany = value;
    _failure = null;
    _notify();
  }

  /// Tapping the chosen status again unsets it — the three are ends of the
  /// line, and there has to be a way back from having picked one by mistake.
  void setStatus(TaskEditStatus? value) {
    _status = _status == value ? null : value;
    _failure = null;
    _notify();
  }

  // ── Saving ──────────────────────────────────────────────────────────────

  /// Everything that is missing, as one line, or null when the sheet is ready.
  String? get _missing {
    if (_chosen[TaskEditField.executor] == null) return 'İcra edən seçin.';
    if (task.source.canEditWorkType &&
        _chosen[TaskEditField.workType] == null) {
      return 'İş növü seçin.';
    }
    if (_dueDate == null) return 'Son müddət seçin.';
    if (_description.trim().isEmpty) return 'Tapşırıq açıqlamasını yazın.';
    return null;
  }

  /// Writes the change back.
  ///
  /// The fields go first and the status second, in that order and never the
  /// other way round: a task that has just been completed is not something the
  /// backend is obliged to keep accepting edits to, and a deadline that
  /// silently failed to save behind a successful `Tamamla` would be the sort of
  /// loss nobody notices until it matters.
  Future<TaskEditOutcome> save() async {
    if (busy) return const TaskEditOutcome(saved: false);
    final String? missing = _missing;
    if (missing != null) {
      _failure = missing;
      _notify();
      return TaskEditOutcome(saved: false, message: missing);
    }
    if (!isDirty) {
      return const TaskEditOutcome(saved: false, message: 'Dəyişiklik yoxdur.');
    }

    _failure = null;
    _progress = 'Yadda saxlanılır…';
    _notify();

    try {
      await _api.save(
        task: task,
        myUserId: _session.user?.id,
        assignedTo: _changedId(TaskEditField.executor),
        workTypeId: _changedId(TaskEditField.workType),
        description: _description.trim() == _originalDescription
            ? null
            : _description.trim(),
        note: _note.trim() == _originalNote ? null : _note.trim(),
        dueDate: _dueDate == _originalDueDate ? null : _dueDate,
        showToCompany:
            !showsVisibility || _showToCompany == _originalShowToCompany
            ? null
            : _showToCompany,
        viewableCompanyId: _myCompanyId,
      );

      final TaskEditStatus? status = _status;
      bool archived = true;
      if (status != null) {
        _progress = 'Status dəyişdirilir…';
        _notify();
        await _api.setStatus(
          task: task,
          status: status,
          myUserId: _session.user?.id,
        );

        // A finished task is filed in the archive by whoever finished it — the
        // backend does not do it, and `Arxiv` is read from the archive and not
        // from the tasks table. See [TaskEditApi.archive].
        if (status == TaskEditStatus.complete) {
          _progress = 'Arxivə köçürülür…';
          _notify();
          archived = await _api.archive(
            task: task,
            myUserId: _session.user?.id,
          );
        }
      }

      _progress = null;
      _notify();
      return TaskEditOutcome(
        saved: true,
        status: status?.status,
        message: status == TaskEditStatus.complete
            ? (archived
                  ? 'Tapşırıq tamamlandı və arxivə köçürüldü.'
                  // Said out loud rather than swallowed: the task really is
                  // completed, and somebody looking for it under `Arxiv`
                  // afterwards needs to know it is not there.
                  : 'Tapşırıq tamamlandı, arxivə köçürülmədi.')
            : null,
      );
    } on ApiException catch (error) {
      _progress = null;
      _failure = error.message;
      _notify();
      return TaskEditOutcome(saved: false, message: error.message);
    }
  }

  /// A picker's answer, but only when it is a different one.
  int? _changedId(TaskEditField field) {
    final TaskOption? now = _chosen[field];
    if (now == null || now.id < 0) return null;
    return now.id == _original[field]?.id ? null : now.id;
  }

  // ── Plumbing ────────────────────────────────────────────────────────────

  String? get _companyCode => _session.user?.companyCode;
  int? get _myCompanyId => _session.user?.companyId;

  Future<void> _load(
    TaskEditField field,
    Future<List<TaskOption>> Function() fetch,
  ) async {
    _set(field, const OptionList.busy());
    try {
      final List<TaskOption> options = await fetch();
      _set(field, OptionList(options: options));
      _reconcile(field, options);
    } on ApiException catch (error) {
      _set(field, OptionList(error: error.message));
    }
  }

  /// Swaps the seeded answer for the real row from the list.
  ///
  /// The card gives a *name*; the list gives a name and an id. Matching them
  /// up is what makes the picker open with the current answer ticked, and what
  /// gives the executor an id on a row whose list endpoint carried only the
  /// name.
  void _reconcile(TaskEditField field, List<TaskOption> options) {
    final TaskOption? seeded = _chosen[field];
    if (seeded == null || options.isEmpty) return;

    TaskOption? match;
    for (final TaskOption option in options) {
      if (option.id == seeded.id) {
        match = option;
        break;
      }
      if (option.name.trim().toLowerCase() ==
          seeded.name.trim().toLowerCase()) {
        match ??= option;
      }
    }
    if (match == null || match == seeded) return;

    _chosen[field] = match;
    // The seeded value was never a change, so neither is this.
    if (_original[field]?.name == seeded.name) _original[field] = match;
    _notify();
  }

  void _set(TaskEditField field, OptionList list) {
    _lists[field] = list;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
