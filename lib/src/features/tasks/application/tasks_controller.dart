import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/application/session_controller.dart';
import '../data/tasks_api.dart';
import '../domain/task_attachment.dart';
import '../domain/task_item.dart';
import '../domain/task_scope.dart';
import '../domain/task_status.dart';

/// One cell of the scope bar: its rows, and how they got there.
@immutable
class TaskScopeState {
  const TaskScopeState({
    this.tasks = const <TaskItem>[],
    this.loading = false,
    this.loaded = false,
    this.error,
  });

  final List<TaskItem> tasks;
  final bool loading;

  /// True once a load has settled, however it settled. Until then the list
  /// shows a spinner rather than "no tasks".
  final bool loaded;
  final String? error;

  TaskScopeState copyWith({
    List<TaskItem>? tasks,
    bool? loading,
    bool? loaded,
    String? error,
    bool clearError = false,
  }) {
    return TaskScopeState(
      tasks: tasks ?? this.tasks,
      loading: loading ?? this.loading,
      loaded: loaded ?? this.loaded,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Drives the Tapşırıqlar screen.
///
/// Each cell of the scope bar keeps its own list, loaded the first time it is
/// selected and kept afterwards, so moving between cells is instant and only a
/// pull-to-refresh goes back to the network.
class TasksController extends ChangeNotifier {
  TasksController(this._session) : _api = TasksApi(_session.client);

  final SessionController _session;
  final TasksApi _api;

  final Map<TaskScope, TaskScopeState> _scopes = <TaskScope, TaskScopeState>{
    for (final TaskScope scope in TaskScope.values) scope: const TaskScopeState(),
  };

  /// Files fetched for a card that has been opened, keyed by task id. Held
  /// here rather than on the card so that closing and reopening one — or a
  /// refresh that rebuilds the list — does not re-request them.
  final Map<int, List<TaskAttachment>> _attachments =
      <int, List<TaskAttachment>>{};

  /// Task ids with a verb in flight. Their buttons show a spinner and stop
  /// accepting taps.
  final Set<int> _busy = <int>{};

  TaskScope _scope = TaskScope.internal;
  TaskScope get scope => _scope;

  bool _disposed = false;

  TaskScopeState get current => _scopes[_scope]!;

  TaskScopeState stateOf(TaskScope scope) => _scopes[scope]!;

  bool isBusy(TaskItem task) => task.id != null && _busy.contains(task.id);

  /// Files already known for [task], or null while they have never been asked
  /// for. Null is what makes the opened card show its own small spinner.
  List<TaskAttachment>? attachmentsOf(TaskItem task) {
    if (task.attachments.isNotEmpty) return task.attachments;
    if (task.attachmentIds.isEmpty) return const <TaskAttachment>[];
    final int? id = task.id;
    return id == null ? const <TaskAttachment>[] : _attachments[id];
  }

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
        TaskScopeState(tasks: tasks, loading: false, loaded: true),
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

  /// Fetches the files of a card that has just been opened, once.
  Future<void> loadAttachments(TaskItem task) async {
    final int? id = task.id;
    if (id == null || _attachments.containsKey(id)) return;
    if (task.attachments.isNotEmpty || task.attachmentIds.isEmpty) return;

    try {
      _attachments[id] = await _api.attachments(task);
    } on ApiException {
      _attachments[id] = const <TaskAttachment>[];
    }
    _notify();
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
    super.dispose();
  }
}
