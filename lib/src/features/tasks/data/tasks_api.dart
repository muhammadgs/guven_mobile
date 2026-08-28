import '../../../core/json.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/task_attachment.dart';
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

  /// How far back `Hesabat` looks until a filter is built to choose a window.
  static const Duration _reportWindow = Duration(days: 90);

  Future<List<TaskItem>> load(TaskScope scope) async {
    final Object? payload = switch (scope) {
      TaskScope.internal => await _client.get(
        '/tasks/detailed',
        query: <String, String>{
          'page': '1',
          'limit': '$_pageSize',
          'include_my_created_tasks': 'true',
        },
      ),
      TaskScope.company => await _client.get(
        '/tasks/external',
        query: <String, String>{'page': '1', 'limit': '$_pageSize'},
      ),
      TaskScope.partner => await _client.get(
        '/partner-tasks/detailed',
        query: <String, String>{'page': '1', 'limit': '$_pageSize'},
      ),
      TaskScope.report => await _client.get(
        '/reports/tasks',
        query: _reportWindowQuery(),
      ),
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

  /// `start_date` and `end_date` are required on the reports endpoint, so the
  /// screen supplies a rolling window rather than leaving the cell empty.
  Map<String, String> _reportWindowQuery() {
    final DateTime now = DateTime.now();
    final DateTime from = now.subtract(_reportWindow);
    return <String, String>{
      'start_date': _day(from),
      'end_date': _day(now),
      'limit': '$_pageSize',
    };
  }

  static String _day(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
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

  /// Expands the file uuids a task row named but did not include.
  ///
  /// Called once, the first time a card is opened, so a list of forty tasks
  /// costs no file requests until somebody asks for one. A file that has since
  /// been deleted 404s; that one is dropped rather than failing the section.
  Future<List<TaskAttachment>> attachments(TaskItem task) async {
    if (task.attachments.isNotEmpty) return task.attachments;
    if (task.attachmentIds.isEmpty) return const <TaskAttachment>[];

    final List<TaskAttachment?> fetched = await Future.wait<TaskAttachment?>(
      task.attachmentIds.map((String id) async {
        try {
          final Map<String, Object?> row = asMap(await _client.get('/files/$id'));
          return TaskAttachment.fromRow(
            row['file'] is Map ? asMap(row['file']) : row,
          );
        } on ApiException {
          return null;
        }
      }),
    );

    return <TaskAttachment>[for (final TaskAttachment? file in fetched) ?file];
  }
}
