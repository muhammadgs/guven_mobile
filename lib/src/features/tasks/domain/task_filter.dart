/// The filter over the task list — the same one the website puts on its
/// table, expressed against rows instead of `<td>`s.
///
/// The site (`assets/js/task_js/ui_ux/column-filter.js`) filters one column at
/// a time, multi-select, and — the part worth copying — **cascades**: the
/// values a column offers are only those still reachable through whatever the
/// *other* columns already have selected, so no combination on offer can ever
/// produce an empty list. All of that is done client-side over the rows
/// already loaded, which is exactly what this does; there is no filter
/// endpoint to call, and the values come from the rows the API returned.
library;

import 'package:flutter/foundation.dart';

import 'task_dates.dart';
import 'task_item.dart';

/// One column of the site's table, and so one row of the filter panel.
///
/// Order is the design's, top to bottom. Four tables on the site each declare
/// their own column list; here every column is offered to every scope and the
/// ones a scope has no values for drop out on their own — `Şöbə` is absent
/// from the site's `external` table for the same reason it will be absent
/// here, because those rows carry no department.
enum TaskFilterField {
  date('Tarix'),
  company('Şirkət'),
  assignedBy('Kim tərəfindən'),
  assignedTo('İcra edən'),
  status('Status'),
  workType('İşin növü'),
  department('Şöbə'),
  dueDate('Son müddət');

  const TaskFilterField(this.label);

  /// What the filter panel calls this column. The site's own header text.
  final String label;

  /// Whether values in this column are days rather than words.
  ///
  /// Dates sort newest-first and everything else alphabetically, the same
  /// split the site makes.
  bool get isDate => this == TaskFilterField.date || this == TaskFilterField.dueDate;

  /// What this task puts in this column, or null when it carries nothing.
  ///
  /// A row with nothing here is not a row with an empty value: it is left out
  /// of the column's options and never matches a selection, which is how the
  /// site treats its `-` cells.
  String? valueOf(TaskItem task) {
    final String? raw = switch (this) {
      TaskFilterField.date =>
        task.createdAt == null ? null : formatTaskDate(task.createdAt!),
      TaskFilterField.dueDate =>
        task.dueDate == null ? null : formatTaskDate(task.dueDate!),
      TaskFilterField.company => task.company,
      TaskFilterField.assignedBy => task.assignedBy,
      TaskFilterField.assignedTo => task.assignedTo,
      TaskFilterField.status => task.status.label,
      TaskFilterField.workType => task.workType,
      TaskFilterField.department => task.department,
    };

    final String value = (raw ?? '').trim();
    // `—` is what `TaskItem.fromRow` fills a missing company or work type
    // with, and `-` is the site's. Neither is a value anybody would filter by.
    if (value.isEmpty || value == '—' || value == '-') return null;
    return value;
  }
}

/// The selections currently in force, keyed by column.
///
/// Empty means "everything", and a column absent from [selections] means
/// "everything in that column" — which is why selecting `Hamısı` deletes the
/// column's entry rather than adding every value to it. Two filters holding
/// the same selections are equal, so the controller can tell a real change
/// from a rebuild.
@immutable
class TaskFilter {
  const TaskFilter([this.selections = const <TaskFilterField, Set<String>>{}]);

  final Map<TaskFilterField, Set<String>> selections;

  static const TaskFilter none = TaskFilter();

  bool get isEmpty => selections.isEmpty;
  bool get isNotEmpty => selections.isNotEmpty;

  /// How many columns are narrowing the list — what the button's badge shows.
  int get activeFieldCount => selections.length;

  Set<String> valuesOf(TaskFilterField field) =>
      selections[field] ?? const <String>{};

  bool isSelected(TaskFilterField field, String value) =>
      selections[field]?.contains(value) ?? false;

  /// Whether [task] survives every column's selections.
  bool matches(TaskItem task) {
    for (final MapEntry<TaskFilterField, Set<String>> entry
        in selections.entries) {
      final String? value = entry.key.valueOf(task);
      if (value == null || !entry.value.contains(value)) return false;
    }
    return true;
  }

  /// [tasks] in their original order, minus the ones that do not match.
  List<TaskItem> apply(List<TaskItem> tasks) {
    if (isEmpty) return tasks;
    return tasks.where(matches).toList(growable: false);
  }

  /// Adds or removes one value in one column.
  TaskFilter toggle(TaskFilterField field, String value) {
    final Set<String> next = Set<String>.of(valuesOf(field));
    if (!next.remove(value)) next.add(value);
    return next.isEmpty ? clear(field) : _with(field, next);
  }

  /// `Hamısı` — the column stops narrowing anything.
  TaskFilter clear(TaskFilterField field) {
    if (!selections.containsKey(field)) return this;
    final Map<TaskFilterField, Set<String>> next =
        Map<TaskFilterField, Set<String>>.of(selections)..remove(field);
    return TaskFilter(Map<TaskFilterField, Set<String>>.unmodifiable(next));
  }

  TaskFilter _with(TaskFilterField field, Set<String> values) {
    final Map<TaskFilterField, Set<String>> next =
        Map<TaskFilterField, Set<String>>.of(selections)
          ..[field] = Set<String>.unmodifiable(values);
    return TaskFilter(Map<TaskFilterField, Set<String>>.unmodifiable(next));
  }

  /// The values [field] can still offer, given every *other* column's
  /// selections — the site's cascade.
  ///
  /// The column being opened is deliberately excluded from the test: without
  /// that, a column that already has one value chosen would offer only the
  /// value already chosen, and nothing could ever be added to it.
  List<String> optionsIn(List<TaskItem> tasks, TaskFilterField field) {
    final TaskFilter others = clear(field);
    final Set<String> values = <String>{};
    for (final TaskItem task in tasks) {
      if (!others.matches(task)) continue;
      final String? value = field.valueOf(task);
      if (value != null) values.add(value);
    }

    final List<String> sorted = values.toList();
    sorted.sort(
      field.isDate
          // Newest day first — `yyyy-MM-dd` sorts as text.
          ? (String a, String b) => b.compareTo(a)
          : (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );
    return sorted;
  }

  /// The columns worth showing for [tasks].
  ///
  /// A column nothing in the list carries — `Şöbə` on the endpoints that do
  /// not return one — is not drawn at all, rather than opening onto an empty
  /// list. A column already narrowing the list stays even if it has only one
  /// option left, so the user can always reach it to switch it off.
  List<TaskFilterField> fieldsIn(List<TaskItem> tasks) {
    return <TaskFilterField>[
      for (final TaskFilterField field in TaskFilterField.values)
        if (selections.containsKey(field) ||
            tasks.any((TaskItem task) => field.valueOf(task) != null))
          field,
    ];
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TaskFilter) return false;
    if (other.selections.length != selections.length) return false;
    for (final MapEntry<TaskFilterField, Set<String>> entry
        in selections.entries) {
      final Set<String>? mine = other.selections[entry.key];
      if (mine == null || !setEquals(mine, entry.value)) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(<Object>[
    for (final MapEntry<TaskFilterField, Set<String>> entry
        in selections.entries)
      Object.hash(entry.key, Object.hashAllUnordered(entry.value)),
  ]);
}
