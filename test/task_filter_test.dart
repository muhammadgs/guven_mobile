import 'package:flutter_test/flutter_test.dart';

import 'package:guven_mobile/src/features/tasks/domain/task_filter.dart';
import 'package:guven_mobile/src/features/tasks/domain/task_item.dart';
import 'package:guven_mobile/src/features/tasks/domain/task_status.dart';

/// The filter is the site's `column-filter.js` rewritten against rows instead
/// of `<td>`s, and the behaviour worth pinning down is the part that is easy
/// to get subtly wrong: the **cascade**. A column's options come from the rows
/// that survive every *other* column, and never from the rows that survive its
/// own — otherwise a column with one value chosen could only ever offer that
/// one value back, and nothing could be added to a selection.
void main() {
  // Four rows that overlap in some columns and not others, so a selection in
  // one column demonstrably changes what another can offer.
  final TaskItem audit = _task(
    id: 1,
    company: 'Rəqəm MMC',
    workType: 'Audit',
    assignedBy: 'Elmar Əzizov',
    assignedTo: 'Nigar Həsənli',
    department: 'AUDİT',
    status: TaskStatus.inProgress,
    createdAt: DateTime(2026, 8, 25, 18, 15),
  );
  final TaskItem ikt = _task(
    id: 2,
    company: 'Rəqəm MMC',
    workType: 'Şəbəkə quraşdırma',
    assignedBy: 'Elmar Əzizov',
    assignedTo: 'Tural Quliyev',
    department: 'İKT',
    status: TaskStatus.pending,
    createdAt: DateTime(2026, 8, 25, 9, 5),
  );
  final TaskItem books = _task(
    id: 3,
    company: 'Ay Ulduz ASC',
    workType: 'Hesabat',
    assignedBy: 'Səbinə Məmmədova',
    assignedTo: 'Nigar Həsənli',
    department: 'Mühasibatlıq',
    status: TaskStatus.inProgress,
    createdAt: DateTime(2026, 8, 24, 11, 0),
  );
  final TaskItem bare = _task(
    id: 4,
    company: '—',
    workType: 'Audit',
    assignedBy: null,
    assignedTo: null,
    department: null,
    status: TaskStatus.paused,
    createdAt: null,
  );

  final List<TaskItem> rows = <TaskItem>[audit, ikt, books, bare];

  group('values', () {
    test('a column offers every value its rows carry, once', () {
      expect(
        TaskFilter.none.optionsIn(rows, TaskFilterField.company),
        <String>['Ay Ulduz ASC', 'Rəqəm MMC'],
      );
    });

    test('placeholders are not values', () {
      // `—` is what a row with no company is filled in with, and `bare` has no
      // department or people at all. Neither is something to filter by.
      expect(
        TaskFilter.none.optionsIn(rows, TaskFilterField.company),
        isNot(contains('—')),
      );
      expect(
        TaskFilter.none.optionsIn(rows, TaskFilterField.department),
        <String>['AUDİT', 'İKT', 'Mühasibatlıq'],
      );
    });

    test('dates are grouped by day, newest first', () {
      expect(
        TaskFilter.none.optionsIn(rows, TaskFilterField.date),
        <String>['2026-08-25', '2026-08-24'],
      );
    });

    test('a column with nothing behind it is not offered at all', () {
      // `Son müddət` — none of these rows has one — and, on the endpoints
      // that return no department, `Şöbə`.
      expect(
        TaskFilter.none.fieldsIn(rows),
        isNot(contains(TaskFilterField.dueDate)),
      );
      expect(
        TaskFilter.none.fieldsIn(<TaskItem>[bare]),
        isNot(contains(TaskFilterField.department)),
      );
      expect(TaskFilter.none.fieldsIn(rows), contains(TaskFilterField.status));
    });
  });

  group('cascade', () {
    test('another column narrows what this one can offer', () {
      final TaskFilter byCompany = TaskFilter.none.toggle(
        TaskFilterField.company,
        'Ay Ulduz ASC',
      );

      expect(
        byCompany.optionsIn(rows, TaskFilterField.department),
        <String>['Mühasibatlıq'],
        reason: 'only the Ay Ulduz row survives, so only its department is '
            'reachable',
      );
    });

    test('a column does not narrow itself', () {
      final TaskFilter oneDepartment = TaskFilter.none.toggle(
        TaskFilterField.department,
        'AUDİT',
      );

      expect(
        oneDepartment.optionsIn(rows, TaskFilterField.department),
        <String>['AUDİT', 'İKT', 'Mühasibatlıq'],
        reason: 'the open column keeps every option, or a second value could '
            'never be added to it',
      );
    });

    test('a column already in force stays on the panel', () {
      // Even once nothing else can reach it — otherwise the row that would
      // switch it off would disappear along with the results.
      final TaskFilter gone = TaskFilter.none.toggle(
        TaskFilterField.dueDate,
        '2026-09-01',
      );
      expect(gone.fieldsIn(rows), contains(TaskFilterField.dueDate));
    });
  });

  group('matching', () {
    test('one column keeps the rows that carry a chosen value', () {
      final TaskFilter filter = TaskFilter.none.toggle(
        TaskFilterField.assignedTo,
        'Nigar Həsənli',
      );
      expect(filter.apply(rows), <TaskItem>[audit, books]);
    });

    test('two values in one column are an "or"', () {
      final TaskFilter filter = TaskFilter.none
          .toggle(TaskFilterField.department, 'AUDİT')
          .toggle(TaskFilterField.department, 'İKT');
      expect(filter.apply(rows), <TaskItem>[audit, ikt]);
    });

    test('two columns are an "and"', () {
      final TaskFilter filter = TaskFilter.none
          .toggle(TaskFilterField.assignedTo, 'Nigar Həsənli')
          .toggle(TaskFilterField.status, TaskStatus.inProgress.label);
      expect(filter.apply(rows), <TaskItem>[audit, books]);

      final TaskFilter narrower = filter.toggle(
        TaskFilterField.company,
        'Rəqəm MMC',
      );
      expect(narrower.apply(rows), <TaskItem>[audit]);
    });

    test('a row carrying nothing in a filtered column is out', () {
      final TaskFilter filter = TaskFilter.none.toggle(
        TaskFilterField.department,
        'AUDİT',
      );
      expect(filter.apply(rows), isNot(contains(bare)));
    });

    test('the order the API returned is kept', () {
      final TaskFilter filter = TaskFilter.none.toggle(
        TaskFilterField.workType,
        'Audit',
      );
      expect(filter.apply(rows), <TaskItem>[audit, bare]);
    });
  });

  group('selections', () {
    test('an empty filter keeps everything, by identity', () {
      expect(TaskFilter.none.apply(rows), same(rows));
      expect(TaskFilter.none.isEmpty, isTrue);
      expect(TaskFilter.none.activeFieldCount, 0);
    });

    test('toggling the last value off clears the column', () {
      final TaskFilter one = TaskFilter.none.toggle(
        TaskFilterField.status,
        TaskStatus.paused.label,
      );
      expect(one.activeFieldCount, 1);

      final TaskFilter off = one.toggle(
        TaskFilterField.status,
        TaskStatus.paused.label,
      );
      expect(off.isEmpty, isTrue, reason: 'no column is left half-selected');
      expect(off.apply(rows), rows);
    });

    test('Hamısı clears the column and leaves the others alone', () {
      final TaskFilter both = TaskFilter.none
          .toggle(TaskFilterField.company, 'Rəqəm MMC')
          .toggle(TaskFilterField.department, 'AUDİT');

      final TaskFilter cleared = both.clear(TaskFilterField.department);
      expect(cleared.valuesOf(TaskFilterField.department), isEmpty);
      expect(cleared.valuesOf(TaskFilterField.company), <String>{'Rəqəm MMC'});
      expect(cleared.apply(rows), <TaskItem>[audit, ikt]);
    });

    test('two filters holding the same selections are equal', () {
      final TaskFilter a = TaskFilter.none
          .toggle(TaskFilterField.company, 'Rəqəm MMC')
          .toggle(TaskFilterField.department, 'AUDİT');
      final TaskFilter b = TaskFilter.none
          .toggle(TaskFilterField.department, 'AUDİT')
          .toggle(TaskFilterField.company, 'Rəqəm MMC');

      // The controller only notifies when the filter actually changed, so
      // this is what keeps a re-tap of the same value from rebuilding the
      // list.
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(b.clear(TaskFilterField.company)));
    });

    test('selecting does not mutate the filter it came from', () {
      final TaskFilter first = TaskFilter.none.toggle(
        TaskFilterField.department,
        'AUDİT',
      );
      first.toggle(TaskFilterField.department, 'İKT');
      expect(first.valuesOf(TaskFilterField.department), <String>{'AUDİT'});
    });
  });
}

TaskItem _task({
  required int id,
  required String company,
  required String workType,
  required TaskStatus status,
  String? assignedBy,
  String? assignedTo,
  String? department,
  DateTime? createdAt,
}) {
  return TaskItem(
    id: id,
    source: TaskSource.internal,
    company: company,
    workType: workType,
    status: status,
    assignedBy: assignedBy,
    assignedTo: assignedTo,
    department: department,
    createdAt: createdAt,
  );
}
