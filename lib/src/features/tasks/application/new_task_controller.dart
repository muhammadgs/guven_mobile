import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;

import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../data/task_create_api.dart';
import '../domain/new_task.dart';
import 'voice_note_recorder.dart';

/// How a send ended.
///
/// [created] and [message] are independent on purpose: a task can exist and
/// still have something worth saying about it — the commonest case being files
/// that uploaded but would not attach, where retrying the whole form would
/// raise the task a second time.
@immutable
class NewTaskOutcome {
  const NewTaskOutcome({required this.created, this.message});

  final bool created;
  final String? message;
}

/// One picker's contents, and how they got there.
@immutable
class OptionList {
  const OptionList({
    this.options = const <TaskOption>[],
    this.loading = false,
    this.error,
    this.notice,
  });

  const OptionList.busy()
    : options = const <TaskOption>[],
      loading = true,
      error = null,
      notice = null;

  /// A list that is deliberately not offered, and says why.
  const OptionList.unavailable(String this.notice)
    : options = const <TaskOption>[],
      loading = false,
      error = null;

  final List<TaskOption> options;
  final bool loading;
  final String? error;

  /// Why this field has nothing to offer, when that is a consequence of an
  /// answer above it rather than a failure — `Digər şirkətin işçisi` while the
  /// company chosen is our own. It stands in for the field's hint as well as
  /// filling the panel, so the answer is visible without opening it.
  final String? notice;

  bool get isEmpty => options.isEmpty && !loading && error == null;
}

/// Drives the `Yeni tapşırıq` sheet: the five lists it offers, the answers
/// given to them, and the several calls it takes to put one task on the
/// backend.
///
/// The cascade is the point. Which company list is offered depends on the
/// kind, and which people, work types and departments are offered depends on
/// the company — because for a [NewTaskKind.company] or
/// [NewTaskKind.partner] task none of those belong to us. Choosing a company
/// therefore drops the three answers under it rather than leaving a work type
/// from one company attached to a task at another.
class NewTaskController extends ChangeNotifier {
  NewTaskController(this._session, {TaskCreateApi? api, VoiceNoteRecorder? voice})
    : _api = api ?? TaskCreateApi(_session.client),
      voice = voice ?? VoiceNoteRecorder() {
    this.voice.addListener(_notify);
  }

  final SessionController _session;
  final TaskCreateApi _api;

  /// The microphone, the wave and the preview player. Owned here so the sheet
  /// can be rebuilt without the recording being interrupted.
  final VoiceNoteRecorder voice;

  NewTaskKind? _kind;
  NewTaskKind? get kind => _kind;

  final Map<NewTaskField, OptionList> _lists = <NewTaskField, OptionList>{
    for (final NewTaskField field in NewTaskField.values)
      field: const OptionList(),
  };

  final Map<NewTaskField, TaskOption> _chosen = <NewTaskField, TaskOption>{};

  DateTime? _dueDate;
  DateTime? get dueDate => _dueDate;

  String _description = '';
  String get description => _description;

  bool _showToCompany = true;
  bool get showToCompany => _showToCompany;

  final List<PendingUpload> _files = <PendingUpload>[];
  List<PendingUpload> get files => List<PendingUpload>.unmodifiable(_files);

  /// Non-null while the task is being sent. Also the line the sheet shows in
  /// place of the buttons, so a slow upload says which file it is on.
  String? _progress;
  String? get progress => _progress;

  bool get busy => _progress != null;

  /// The last refusal — a missing field, or the backend's own words.
  String? _failure;
  String? get failure => _failure;

  bool _disposed = false;

  OptionList listOf(NewTaskField field) => _lists[field]!;
  TaskOption? chosen(NewTaskField field) => _chosen[field];

  /// The fields this kind actually asks for, in the order the design draws
  /// them.
  List<NewTaskField> get fields => <NewTaskField>[
    NewTaskField.company,
    if (_kind?.hasOwnExecutor ?? false) NewTaskField.executor,
    NewTaskField.otherWorker,
    NewTaskField.workType,
    NewTaskField.department,
  ];

  String? get _companyCode => _session.user?.companyCode;
  int? get _myCompanyId => _session.user?.companyId;
  String? get _myCompanyName => _session.user?.companyName;

  // ── Opening ─────────────────────────────────────────────────────────────

  /// Starts a form of [kind] and fetches everything it can before a company
  /// has been picked.
  void begin(NewTaskKind kind) {
    if (_kind == kind) return;
    _kind = kind;
    _chosen.clear();
    _failure = null;
    for (final NewTaskField field in NewTaskField.values) {
      _lists[field] = const OptionList();
    }
    _notify();

    unawaited(_loadCompanies());
    if (kind.hasOwnExecutor) {
      // Our own people carry out our own tasks, whoever the task is *for*.
      unawaited(_load(NewTaskField.executor, () => _employeesOfMine()));
      unawaited(_load(NewTaskField.workType, () => _workTypesOfMine()));
      unawaited(_load(NewTaskField.department, () => _departmentsOfMine()));
    }
  }

  Future<void> _loadCompanies() async {
    final NewTaskKind? kind = _kind;
    final String? code = _companyCode;
    if (kind == null || code == null) {
      _set(
        NewTaskField.company,
        const OptionList(error: 'Şirkət kodunuz məlum deyil.'),
      );
      return;
    }

    await _load(NewTaskField.company, () async {
      final List<TaskOption> options = switch (kind) {
        // Our own company heads the list and is selected: most internal work
        // is our own, and the sub-companies below it are the customers a task
        // can be raised *for*.
        NewTaskKind.internal => <TaskOption>[
          if (_myCompanyId != null)
            TaskOption(
              id: _myCompanyId!,
              name: _myCompanyName ?? code,
              code: code,
              isMine: true,
            ),
          ...await _api.subCompanies(code),
        ],
        NewTaskKind.company => await _api.parentCompanies(code),
        NewTaskKind.partner => await _api.partners(code),
      };
      return options;
    });

    final OptionList list = listOf(NewTaskField.company);
    if (list.options.isNotEmpty && _chosen[NewTaskField.company] == null) {
      final TaskOption first = list.options.firstWhere(
        (TaskOption option) => option.isMine,
        orElse: () => list.options.first,
      );
      // Only the internal form opens with a company already chosen; on the
      // other two the choice decides whose people and work types are offered,
      // and choosing it for the user would hide that.
      if (first.isMine) choose(NewTaskField.company, first);
    }
  }

  // ── Answering ───────────────────────────────────────────────────────────

  void choose(NewTaskField field, TaskOption option) {
    _chosen[field] = option;
    _failure = null;
    if (field == NewTaskField.company) _onCompanyChosen(option);
    _notify();
  }

  /// A company decides who and what is available under it.
  void _onCompanyChosen(TaskOption company) {
    final NewTaskKind? kind = _kind;
    if (kind == null) return;

    _chosen.remove(NewTaskField.otherWorker);
    final String? code = company.code;
    if (company.isMine) {
      // `Digər şirkətin işçisi` is a watcher on the *other* side of the task.
      // With our own company chosen there is no other side, and offering our
      // own people here — which is what asking for this company's employees
      // does — reads as a second `İcra edən`. The field says what to do about
      // it instead of listing the wrong people.
      _set(
        NewTaskField.otherWorker,
        const OptionList.unavailable('Digər şirkət seçin'),
      );
    } else {
      unawaited(
        _load(
          NewTaskField.otherWorker,
          () => code == null
              ? Future<List<TaskOption>>.value(const <TaskOption>[])
              : _api.employees(code),
        ),
      );
    }

    // On a task handed to another company, the work type and the department
    // are that company's — ours mean nothing there.
    if (!kind.hasOwnExecutor) {
      _chosen
        ..remove(NewTaskField.workType)
        ..remove(NewTaskField.department);
      unawaited(
        _load(
          NewTaskField.workType,
          () => _api.workTypes(company.realCompanyId),
        ),
      );
      unawaited(
        _load(
          NewTaskField.department,
          () => code == null
              ? Future<List<TaskOption>>.value(const <TaskOption>[])
              : _api.departments(code),
        ),
      );
    }
  }

  void setDueDate(DateTime? day) {
    _dueDate = day;
    _failure = null;
    _notify();
  }

  void setDescription(String text) {
    _description = text;
    _failure = null;
  }

  void setShowToCompany(bool value) {
    _showToCompany = value;
    _notify();
  }

  // ── Files ───────────────────────────────────────────────────────────────

  /// Opens the phone's picker and keeps whatever comes back.
  ///
  /// The bytes are read here rather than at submit time: a document picked out
  /// of a cloud provider is handed over as a temporary copy, and that copy is
  /// not guaranteed to still be there minutes later when the form is sent.
  Future<void> addFiles() async {
    try {
      final List<PlatformFile> picked = await FilePicker.pickFiles();
      for (final PlatformFile file in picked) {
        _files.add(
          PendingUpload(
            name: file.name,
            bytes: await file.readAsBytes(),
            mimeType: mimeTypeForName(file.name),
          ),
        );
      }
      _notify();
    } on MissingPluginException {
      _failure = 'Tətbiqi yenidən qurmaq lazımdır (fayl seçmə modulu yoxdur).';
      _notify();
    } on PlatformException {
      _failure = 'Fayl seçilə bilmədi.';
      _notify();
    } on FileSystemException {
      _failure = 'Fayl oxuna bilmədi.';
      _notify();
    }
  }

  void removeFile(PendingUpload file) {
    _files.remove(file);
    _notify();
  }

  // ── Sending ─────────────────────────────────────────────────────────────

  /// Everything that is missing, as one line, or null when the form is ready.
  String? get _missing {
    final NewTaskKind? kind = _kind;
    if (kind == null) return 'Tapşırıq növü seçilməyib.';
    if (_chosen[NewTaskField.company] == null) {
      return '${kind.companyLabel} seçin.';
    }
    if (kind.hasOwnExecutor && _chosen[NewTaskField.executor] == null) {
      return 'İcra edən seçin.';
    }
    if (!kind.hasOwnExecutor && _chosen[NewTaskField.otherWorker] == null) {
      return '${kind.otherWorkerLabel} seçin.';
    }
    if (_chosen[NewTaskField.workType] == null) return 'İş növü seçin.';
    if (_chosen[NewTaskField.department] == null) return 'Şöbə seçin.';
    if (_dueDate == null) return 'Son müddət seçin.';
    if (_description.trim().isEmpty) return 'Tapşırıq açıqlamasını yazın.';
    return null;
  }

  /// Creates the task.
  ///
  /// Files are uploaded first because an internal task carries their uuids in
  /// its own create call; the other two resources are updated afterwards. A
  /// failure *after* the task exists is reported without pretending the task
  /// does not — losing an attachment is worth saying, and raising the same
  /// task a second time trying to fix it is not.
  Future<NewTaskOutcome> submit() async {
    if (busy) return const NewTaskOutcome(created: false);
    final String? missing = _missing;
    if (missing != null) {
      _failure = missing;
      _notify();
      return NewTaskOutcome(created: false, message: missing);
    }

    final NewTaskKind kind = _kind!;
    _failure = null;
    _progress = 'Hazırlanır…';
    _notify();

    try {
      final List<PendingUpload> uploads = <PendingUpload>[
        ..._files,
        ...await voice.collect(),
      ];

      final List<String> uuids = <String>[];
      for (int i = 0; i < uploads.length; i++) {
        _progress = 'Fayllar yüklənir (${i + 1}/${uploads.length})…';
        _notify();
        uuids.add(await _api.upload(uploads[i]));
      }

      _progress = 'Tapşırıq yaradılır…';
      _notify();

      final int taskId = await _api.create(
        kind: kind,
        company: _chosen[NewTaskField.company]!,
        // On the internal form the executor is one of ours and the other
        // company's person is only watching; on the other two there is no
        // executor of ours and that person *is* the executor.
        assignedTo:
            (_chosen[NewTaskField.executor] ??
                    _chosen[NewTaskField.otherWorker])
                ?.id,
        watcher: kind.hasOwnExecutor
            ? _chosen[NewTaskField.otherWorker]
            : null,
        workType: _chosen[NewTaskField.workType]!,
        department: _chosen[NewTaskField.department]!,
        dueDate: _dueDate!,
        description: _description.trim(),
        showToCompany: kind.hasVisibilityToggle && _showToCompany,
        fileUuids: uuids,
        myCompanyId: _myCompanyId,
        myCompanyName: _myCompanyName,
        myUserId: _session.user?.id,
        myName: _session.user?.fullName,
      );

      // The internal create call already carried them.
      if (uuids.isNotEmpty && kind != NewTaskKind.internal) {
        try {
          await _api.attachFiles(
            source: kind.source,
            taskId: taskId,
            uuids: uuids,
            myUserId: _session.user?.id,
          );
        } on ApiException {
          _progress = null;
          _notify();
          return const NewTaskOutcome(
            created: true,
            message: 'Tapşırıq yaradıldı, amma fayllar ona bağlanmadı.',
          );
        }
      }

      _progress = null;
      _notify();
      return const NewTaskOutcome(created: true);
    } on ApiException catch (error) {
      _progress = null;
      _failure = error.message;
      _notify();
      return NewTaskOutcome(created: false, message: error.message);
    }
  }

  // ── Plumbing ────────────────────────────────────────────────────────────

  Future<void> _load(
    NewTaskField field,
    Future<List<TaskOption>> Function() fetch,
  ) async {
    _set(field, const OptionList.busy());
    try {
      _set(field, OptionList(options: await fetch()));
    } on ApiException catch (error) {
      _set(field, OptionList(error: error.message));
    }
  }

  Future<List<TaskOption>> _employeesOfMine() {
    final String? code = _companyCode;
    if (code == null) return Future<List<TaskOption>>.value(const <TaskOption>[]);
    return _api.employees(code);
  }

  Future<List<TaskOption>> _departmentsOfMine() {
    final String? code = _companyCode;
    if (code == null) return Future<List<TaskOption>>.value(const <TaskOption>[]);
    return _api.departments(code);
  }

  Future<List<TaskOption>> _workTypesOfMine() {
    final int? id = _myCompanyId;
    if (id == null) return Future<List<TaskOption>>.value(const <TaskOption>[]);
    return _api.workTypes(id);
  }

  void _set(NewTaskField field, OptionList list) {
    _lists[field] = list;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    voice.removeListener(_notify);
    voice.dispose();
    super.dispose();
  }
}
