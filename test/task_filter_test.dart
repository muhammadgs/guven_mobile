import 'package:flutter_test/flutter_test.dart';

import 'package:guven_mobile/src/features/database/domain/database_filter.dart';
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

  group('a span of days', () {
    FilterRange days(DateTime? from, DateTime? to) => FilterRange(
      min: from == null ? null : filterDayOf(from).toDouble(),
      max: to == null ? null : filterDayOf(to).toDouble(),
    );

    test('holds every task on its first and last day, whatever the hour', () {
      final TaskFilter filter = TaskFilter.none.withRange(
        TaskFilterField.date,
        days(DateTime(2026, 8, 25), DateTime(2026, 8, 25)),
      );
      expect(filter.apply(rows), <TaskItem>[audit, ikt]);
      expect(filter.activeFieldCount, 1);
    });

    test('an open end lets everything past it through', () {
      final TaskFilter filter = TaskFilter.none.withRange(
        TaskFilterField.date,
        days(null, DateTime(2026, 8, 24)),
      );
      // The task with no date is in no span at all.
      expect(filter.apply(rows), <TaskItem>[books]);
    });

    test('a span and ticked days are one or the other', () {
      final TaskFilter ticked = TaskFilter.none.toggle(
        TaskFilterField.date,
        '2026-08-24',
      );
      final TaskFilter spanned = ticked.withRange(
        TaskFilterField.date,
        days(DateTime(2026, 8, 25), null),
      );
      expect(spanned.valuesOf(TaskFilterField.date), isEmpty);
      expect(spanned.narrows(TaskFilterField.date), isTrue);

      final TaskFilter back = spanned.toggle(TaskFilterField.date, '2026-08-24');
      expect(back.rangeOf(TaskFilterField.date), FilterRange.any);
      expect(back.apply(rows), <TaskItem>[books]);

      // An empty span leaves the ticked days alone.
      expect(
        back.withRange(TaskFilterField.date, FilterRange.any),
        back,
      );
      expect(back.clear(TaskFilterField.date), TaskFilter.none);
    });

    test('a day is read the way it is typed', () {
      final DateTime today = DateTime(2026, 11, 8);
      expect(
        parseFilterDay('25.08.2026'),
        filterDayOf(DateTime(2026, 8, 25)),
      );
      expect(
        parseFilterDay('25.08', today: today),
        filterDayOf(DateTime(2026, 8, 25)),
      );
      expect(
        parseFilterDay('25.08.', today: today),
        filterDayOf(DateTime(2026, 8, 25)),
      );
      // A year not typed out yet, a day the calendar lacks, nothing.
      expect(parseFilterDay('25.08.20'), isNull);
      expect(parseFilterDay('31.02.2026'), isNull);
      expect(parseFilterDay('25'), isNull);
      expect(parseFilterDay(''), isNull);
      expect(writeFilterDay(filterDayOf(DateTime(2026, 6, 1))), '01.06.2026');
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
