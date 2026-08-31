import '../../../core/json.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/task_item.dart';
import '../domain/task_scope.dart';
import '../domain/task_status.dart';

/// Everything the Tapşırıqlar screen asks the backend for.
///
/// Five list endpoints — one per cell of the scope bar — plus the verbs the
/// card's buttons fire. The verbs are spelled the same on all three task
/// resources, so the path prefix comes off the row itself
/// ([TaskSource.pathPrefix]) rather than being branched on here.
class TasksApi {
  const TasksApi(this._client);

  final ApiClient _client;

  /// How many rows a cell loads. The list is not paged yet; the site's own
  /// task table opens at a hundred rows too.
  static const int _pageSize = 100;

  /// What the three live lists ask for and what they keep.
  ///
  /// The website's active table sends exactly this set minus `rejected`;
  /// finished and cancelled work belongs to `Arxiv` and must not appear in
  /// `Daxili`, `Şirkət` or `Partniyor`. Refusals stay, by instruction, until
  /// they get a home of their own.
  ///
  /// `status` is a hint to these endpoints rather than a guarantee — a
  /// deployment that ignores it would put completed tasks back in the list —
  /// so what comes back is filtered against the same set again.
  static const List<String> _openStatuses = <String>[
    'pending_approval',
    'approval_overdue',
    'pending',
    'in_progress',
    'overdue',
    'waiting',
    'paused',
    'rejected',
  ];

  Future<List<TaskItem>> load(TaskScope scope) async {
    // `Hesabat` is deliberately empty: it is being designed as something other
    // than a task list, so nothing is fetched for it.
    if (!scope.hasFeed) return const <TaskItem>[];

    final Object? payload = switch (scope) {
      TaskScope.internal => await _client.get(
        '/tasks/detailed',
        query: <String, String>{
          'page': '1',
          'limit': '$_pageSize',
          'include_my_created_tasks': 'true',
          'status': _openStatuses.join(','),
        },
      ),
      // `/tasks-external/` — "the current company's viewable external tasks" —
      // and not `/tasks/external`, which is a different endpoint entirely:
      // that one returns *other companies'* tasks (`exclude_my_company` is
      // true by default), so `Şirkət` was showing work that has nothing to do
      // with this relationship. A cross-company task is one we handed up to an
      // executor company of ours, or one handed to us; a company with no
      // parent companies has none, and this endpoint correctly answers with
      // nothing. It is also the resource `POST /tasks-external/` writes to and
      // the one the website's own external table reads.
      TaskScope.company => await _client.get(
        '/tasks-external/',
        query: <String, String>{
          'page': '1',
          'limit': '$_pageSize',
          'status': _openStatuses.join(','),
        },
      ),
      // `/partner-tasks/detailed` takes no `status`, so this one is filtered
      // on the way out and nowhere else.
      TaskScope.partner => await _client.get(
        '/partner-tasks/detailed',
        query: <String, String>{'page': '1', 'limit': '$_pageSize'},
      ),
      TaskScope.report => null,
      TaskScope.archive => await _client.get(
        '/task-archive/',
        query: <String, String>{'page': '1', 'limit': '$_pageSize'},
      ),
    };

    final List<Map<String, Object?>> rows = asRows(
      payload,
      keys: <String>['tasks', 'partner_tasks', 'archives', 'archived_tasks'],
    );

    final List<TaskItem> items = <TaskItem>[
      for (final Map<String, Object?> row in rows)
        TaskItem.fromRow(row, scope.source),
    ];

    // Finished work lives in `Arxiv`, so the three live lists never show it.
    if (scope != TaskScope.archive) {
      items.removeWhere(
        (TaskItem task) =>
            task.status == TaskStatus.completed ||
            task.status == TaskStatus.cancelled ||
            task.status == TaskStatus.archived,
      );
    }

    // Newest first, undated last — the order the site's table opens in.
    items.sort((TaskItem a, TaskItem b) {
      final DateTime? left = a.createdAt;
      final DateTime? right = b.createdAt;
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });
    return items;
  }

  /// Fires one of the card's buttons.
  ///
  /// Returns the status the task should now be in. Each verb does answer with
  /// the updated row, but not consistently enough across the three resources
  /// to read the one field the card needs, so the next status is derived from
  /// the verb and the list is refreshed behind it.
  Future<TaskStatus> run(TaskAction action, TaskItem task) async {
    final int? id = task.id;
    if (id == null || !task.source.isActionable) {
      throw const ApiException('Bu tapşırıq üzərində əməliyyat mümkün deyil.');
    }
    final String base = '${task.source.pathPrefix}/$id';

    switch (action) {
      case TaskAction.approve:
        await _client.post('$base/approve');
        return TaskStatus.pending;
      case TaskAction.reject:
        await _client.post(
          '$base/reject-approval',
          body: <String, Object?>{'reason': ''},
        );
        return TaskStatus.rejected;
      case TaskAction.start:
        await _client.post('$base/start');
        return TaskStatus.inProgress;
      case TaskAction.pause:
        await _client.post(
          '$base/pause',
          body: <String, Object?>{'reason': ''},
        );
        return TaskStatus.paused;
      case TaskAction.resume:
        await _client.post('$base/resume');
        return TaskStatus.inProgress;
      case TaskAction.edit:
        throw const ApiException('Redaktə bölməsi hazırlanır.');
    }
  }

}
