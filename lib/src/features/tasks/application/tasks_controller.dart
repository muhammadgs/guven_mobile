import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../data/task_files_api.dart';
import '../data/tasks_api.dart';
import '../domain/task_attachment.dart';
import '../domain/task_filter.dart';
import '../domain/task_item.dart';
import '../domain/task_scope.dart';
import '../domain/task_status.dart';
import 'task_voice_player.dart';

/// One cell of the scope bar: its rows, and how they got there.
@immutable
class TaskScopeState {
  const TaskScopeState({
    this.tasks = const <TaskItem>[],
    this.loading = false,
    this.loaded = false,
    this.error,
    this.filter = TaskFilter.none,
  });

  final List<TaskItem> tasks;
  final bool loading;

  /// True once a load has settled, however it settled. Until then the list
  /// shows a spinner rather than "no tasks".
  final bool loaded;
  final String? error;

  /// The columns currently narrowing this cell.
  ///
  /// Per cell, not per screen: the values differ between them — a name that
  /// exists in `Daxili` need not exist in `Arxiv` — so one shared filter would
  /// empty a list the moment the user changed cell.
  final TaskFilter filter;

  /// The rows the list draws: [tasks] minus whatever [filter] excludes.
  List<TaskItem> get visible => filter.apply(tasks);

  TaskScopeState copyWith({
    List<TaskItem>? tasks,
    bool? loading,
    bool? loaded,
    String? error,
    TaskFilter? filter,
    bool clearError = false,
  }) {
    return TaskScopeState(
      tasks: tasks ?? this.tasks,
      loading: loading ?? this.loading,
      loaded: loaded ?? this.loaded,
      error: clearError ? null : (error ?? this.error),
      filter: filter ?? this.filter,
    );
  }
}

/// Drives the Tapşırıqlar screen.
///
/// Each cell of the scope bar keeps its own list, loaded the first time it is
/// selected and kept afterwards, so moving between cells is instant and only a
/// pull-to-refresh goes back to the network.
class TasksController extends ChangeNotifier {
  /// [api] and [files] are the seam the tests reach through: everything on
  /// this screen is driven by what the list endpoints answered, so a test that
  /// cannot choose the rows cannot say anything about the filter over them.
  TasksController(this._session, {TasksApi? api, TaskFilesApi? files})
    : _api = api ?? TasksApi(_session.client),
      _files = files ?? TaskFilesApi(_session.client) {
    voice = TaskVoicePlayer(_files);
  }

  final SessionController _session;
  final TasksApi _api;
  final TaskFilesApi _files;

  /// The one player behind every `Səs qeydləri` row on this screen.
  ///
  /// Deliberately *not* wired into this controller's own notifications: it
  /// ticks ten times a second while a note plays, and rebuilding the whole
  /// task list at that rate to move one waveform would be absurd. The cards
  /// listen to it directly, around the section that actually changes.
  late final TaskVoicePlayer voice;

  final Map<TaskScope, TaskScopeState> _scopes = <TaskScope, TaskScopeState>{
    for (final TaskScope scope in TaskScope.values)
      scope: const TaskScopeState(),
  };

  /// Files described for a card that has been opened, keyed by task id. Held
  /// here rather than on the card so that closing and reopening one — or a
  /// refresh that rebuilds the list — does not describe them again.
  final Map<int, List<TaskAttachment>> _attachments =
      <int, List<TaskAttachment>>{};

  /// Task ids with a verb in flight. Their buttons show a spinner and stop
  /// accepting taps.
  final Set<int> _busy = <int>{};

  /// File ids currently being downloaded, so a chip that has been tapped shows
  /// a spinner and a second tap does not start a second download.
  final Set<String> _opening = <String>{};

  TaskScope _scope = TaskScope.internal;
  TaskScope get scope => _scope;

  bool _disposed = false;

  TaskScopeState get current => _scopes[_scope]!;

  TaskScopeState stateOf(TaskScope scope) => _scopes[scope]!;

  bool isBusy(TaskItem task) => task.id != null && _busy.contains(task.id);

  /// The files to draw on [task]'s card, or null while they are still being
  /// described. Null is what makes an opened card show its own small spinner.
  List<TaskAttachment>? attachmentsOf(TaskItem task) {
    if (!task.hasAttachments) return const <TaskAttachment>[];
    if (!task.needsFileDetails) return task.attachments;
    final int? id = task.id;
    return id == null ? task.attachments : _attachments[id];
  }

  /// The files being downloaded right now, for the chips that should be
  /// showing a spinner.
  Set<String> get openingFileIds => _opening;

  /// Who is signed in, for the "this one is mine" test the cards make.
  int? get myUserId => _session.user?.id;
  String? get myFullName => _session.user?.fullName;

  void select(TaskScope next) {
    if (next == _scope) return;
    _scope = next;
    _notify();
    // A cell that has never been opened loads on arrival; one that has keeps
    // what it had until the user pulls to refresh.
    if (!_scopes[next]!.loaded && !_scopes[next]!.loading) load(next);
  }

  // ── The filter ──────────────────────────────────────────────────────────
  //
  // Everything here works over the rows already in hand. The site's own
  // column filter does the same: there is no filter endpoint, the values a
  // column offers are the values its rows carry, and narrowing the list is
  // never a request.

  /// The selections in force on the cell being shown.
  TaskFilter get filter => current.filter;

  /// The rows the list should draw right now.
  List<TaskItem> get visibleTasks => current.visible;

  /// The columns the panel offers for this cell — those its rows carry.
  List<TaskFilterField> get filterFields =>
      current.filter.fieldsIn(current.tasks);

  /// What [field] can still be narrowed to, given the other columns.
  List<String> filterOptions(TaskFilterField field) =>
      current.filter.optionsIn(current.tasks, field);

  /// Adds or removes one value in one column.
  void toggleFilter(TaskFilterField field, String value) =>
      _setFilter(current.filter.toggle(field, value));

  /// `Hamısı` — [field] stops narrowing anything.
  void clearFilterField(TaskFilterField field) =>
      _setFilter(current.filter.clear(field));

  /// Drops every column's selections on this cell.
  void clearFilter() => _setFilter(TaskFilter.none);

  void _setFilter(TaskFilter next) {
    if (next == current.filter) return;
    _set(_scope, current.copyWith(filter: next));
  }

  /// Loads one cell. Defaults to the selected one, which is what
  /// pull-to-refresh hands it.
  Future<void> load([TaskScope? which]) async {
    final TaskScope scope = which ?? _scope;
    if (_scopes[scope]!.loading) return;

    _set(scope, _scopes[scope]!.copyWith(loading: true, clearError: true));
    try {
      final List<TaskItem> tasks = await _api.load(scope);
      _set(
        scope,
        // The filter survives a refresh, the way the site's does: a pull is a
        // request for newer rows, not a request to see all of them again.
        TaskScopeState(
          tasks: tasks,
          loading: false,
          loaded: true,
          filter: _scopes[scope]!.filter,
        ),
      );
    } on ApiException catch (error) {
      // A 401 has already signed the session out inside the client; putting a
      // message on a screen that is being torn down helps nobody.
      _set(
        scope,
        _scopes[scope]!.copyWith(
          loading: false,
          loaded: true,
          error: error.isUnauthorized ? null : error.message,
          clearError: error.isUnauthorized,
        ),
      );
    }
  }

  /// Runs a card's button.
  ///
  /// The new status lands on the card straight away and the cell is refreshed
  /// behind it, so the button pair swaps at the speed of the tap rather than
  /// the speed of the round trip. Returns the failure message, or null when it
  /// worked — the screen turns that into a snack bar.
  Future<String?> run(TaskAction action, TaskItem task) async {
    final int? id = task.id;
    if (id == null) return 'Bu tapşırığın nömrəsi yoxdur.';
    if (_busy.contains(id)) return null;

    _busy.add(id);
    _notify();
    try {
      final TaskStatus next = await _api.run(action, task);
      _replace(task, task.copyWith(status: next));
      unawaited(load(_scope));
      return null;
    } on ApiException catch (error) {
      return error.message;
    } finally {
      _busy.remove(id);
      _notify();
    }
  }

  /// Takes what the `Redaktə` sheet just wrote.
  ///
  /// A status the sheet set lands on the card straight away — same reason as
  /// [run]'s: the chip swaps at the speed of the tap rather than of the round
  /// trip — and the cell is refetched behind it, because the sheet may also
  /// have changed the executor, the deadline or the work type, none of which
  /// this screen can guess.
  void applyEdit(TaskItem task, {TaskStatus? status}) {
    if (status != null) _replace(task, task.copyWith(status: status));
    unawaited(load(_scope));
  }

  /// Works out what the files on a just-opened card actually are, once.
  ///
  /// A task row names its files as bare uuids, so until this runs the card
  /// knows it has three files and nothing else about them. Deferring it to the
  /// first open is what keeps a list of forty tasks from making a hundred
  /// probe requests nobody asked for.
  Future<void> loadAttachments(TaskItem task) async {
    final int? id = task.id;
    if (id == null || _attachments.containsKey(id)) return;
    if (!task.needsFileDetails) return;

    try {
      _attachments[id] = await _files.describe(task.attachments);
    } on ApiException {
      // Undescribed files still open — the phone works the type out from the
      // download itself — so they are kept rather than dropped.
      _attachments[id] = task.attachments;
    }
    _notify();
  }

  /// Downloads a file and hands it to whatever the phone opens that type with.
  ///
  /// Returns the message to show, or null when it opened. The bytes are cached
  /// for the session, so reopening the same file is instant.
  Future<String?> openAttachment(TaskAttachment file) async {
    if (_opening.contains(file.id)) return null;
    _opening.add(file.id);
    _notify();
    try {
      return switch (await _files.open(file)) {
        FileOpenResult.opened => null,
        FileOpenResult.noHandler =>
          'Bu faylı açacaq proqram tapılmadı: ${file.label}',
        FileOpenResult.failed => 'Fayl açıla bilmədi.',
        FileOpenResult.notInstalled =>
          'Tətbiqi yenidən qurmaq lazımdır (fayl açma modulu yoxdur).',
      };
    } finally {
      _opening.remove(file.id);
      _notify();
    }
  }

  void _replace(TaskItem old, TaskItem next) {
    final TaskScopeState state = _scopes[_scope]!;
    final int index = state.tasks.indexOf(old);
    if (index < 0) return;
    final List<TaskItem> tasks = List<TaskItem>.of(state.tasks);
    tasks[index] = next;
    _set(_scope, state.copyWith(tasks: tasks));
  }

  void _set(TaskScope scope, TaskScopeState state) {
    _scopes[scope] = state;
    _notify();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    voice.dispose();
    super.dispose();
  }
}
