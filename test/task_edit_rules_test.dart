import 'package:flutter_test/flutter_test.dart';

import 'package:guven_mobile/src/features/tasks/domain/task_edit.dart';
import 'package:guven_mobile/src/features/tasks/domain/task_item.dart';
import 'package:guven_mobile/src/features/tasks/domain/task_status.dart';

/// Who may open `Redaktə`, and what the card offers them.
///
/// Two people and no others — the person carrying the task out and the person
/// who raised it. That rule is the whole reason [TaskItem.assignedById] is
/// read, and getting it wrong in either direction is a real fault: too narrow
/// and a manager cannot fix a deadline they set themselves, too wide and
/// anyone in the company can rewrite anyone's work.
void main() {
  TaskItem task({
    TaskStatus status = TaskStatus.inProgress,
    TaskSource source = TaskSource.internal,
    int? assignedToId = 7,
    String? assignedTo = 'Əli Balakişiyev',
    int? assignedById = 4,
    String? assignedBy = 'Məhəmməd Qasımov',
  }) {
    return TaskItem(
      id: 12,
      source: source,
      company: 'Güvən Finans MMC',
      workType: 'Frontend',
      status: status,
      assignedBy: assignedBy,
      assignedById: assignedById,
      assignedTo: assignedTo,
      assignedToId: assignedToId,
    );
  }

  group('canEdit', () {
    test('the executor may', () {
      expect(task().canEdit(userId: 7), isTrue);
    });

    test('whoever raised it may', () {
      expect(task().canEdit(userId: 4), isTrue);
    });

    test('nobody else may', () {
      expect(task().canEdit(userId: 99), isFalse);
    });

    test('a name stands in where the row carries no ids', () {
      final TaskItem row = task(assignedToId: null, assignedById: null);
      expect(row.canEdit(fullName: 'əli balakişiyev'), isTrue);
      expect(row.canEdit(fullName: 'Məhəmməd Qasımov'), isTrue);
      expect(row.canEdit(fullName: 'Kimsə Başqası'), isFalse);
    });

    test('finished work is a record, not a plan', () {
      for (final TaskStatus done in <TaskStatus>[
        TaskStatus.completed,
        TaskStatus.cancelled,
        TaskStatus.rejected,
        TaskStatus.archived,
      ]) {
        expect(task(status: done).canEdit(userId: 7), isFalse, reason: '$done');
      }
    });

    test('an archive row has no endpoint to write to', () {
      expect(task(source: TaskSource.readOnly).canEdit(userId: 7), isFalse);
    });
  });

  group('the buttons a card offers', () {
    test('the executor keeps the verbs they had', () {
      expect(
        actionsFor(TaskStatus.inProgress, mine: true, canEdit: true),
        <TaskAction>[TaskAction.pause, TaskAction.edit],
      );
    });

    test('a task waiting to be accepted is still only accepted or refused', () {
      expect(
        actionsFor(TaskStatus.pendingApproval, mine: true, canEdit: true),
        <TaskAction>[TaskAction.approve, TaskAction.reject],
      );
    });

    test('a creator who is not the executor gets Redaktə and nothing else', () {
      expect(
        actionsFor(TaskStatus.inProgress, mine: false, canEdit: true),
        <TaskAction>[TaskAction.edit],
      );
    });

    test('everybody else gets no buttons at all', () {
      expect(actionsFor(TaskStatus.inProgress, mine: false), isEmpty);
    });

    test('a state with no verbs still offers the editor to the two', () {
      expect(
        actionsFor(TaskStatus.inReview, mine: true, canEdit: true),
        <TaskAction>[TaskAction.edit],
      );
      expect(actionsFor(TaskStatus.inReview, mine: true), isEmpty);
    });
  });

  group('what each resource can store', () {
    test('a partner task has no work type and no visibility flag', () {
      expect(TaskSource.partner.canEditWorkType, isFalse);
      expect(TaskSource.partner.canEditVisibility, isFalse);
      expect(TaskSource.partner.noteField, 'partner_notes');
    });

    test('internal and cross-company tasks take the same free-form PATCH', () {
      for (final TaskSource source in <TaskSource>[
        TaskSource.internal,
        TaskSource.external,
      ]) {
        expect(source.hasFreeFormUpdate, isTrue, reason: '$source');
        expect(source.canEditWorkType, isTrue, reason: '$source');
        expect(source.noteField, 'notes', reason: '$source');
      }
    });

    test('…but they are three tables, addressed three different ways', () {
      // Their ids are separate sequences — `POST /tasks-external/sync/{id}`
      // exists to copy a row from one into the other — so a shared prefix
      // would not fail, it would rewrite whichever task happens to hold that
      // number in the wrong table.
      expect(TaskSource.internal.pathPrefix, '/tasks');
      expect(TaskSource.external.pathPrefix, '/tasks-external');
      expect(TaskSource.partner.pathPrefix, '/partner-tasks');
      expect(
        <TaskSource>[
          TaskSource.internal,
          TaskSource.external,
          TaskSource.partner,
        ].map((TaskSource s) => s.pathPrefix).toSet(),
        hasLength(3),
      );
    });

    test('each kind is filed in its own archive list', () {
      expect(TaskSource.internal.archivePath, '/task-archive/archive');
      expect(TaskSource.external.archivePath, '/task-archive/archive-external');
      expect(TaskSource.partner.archivePath, '/task-archive/archive-partner');
    });

    test('the three ends are spelled the way the backend spells them', () {
      expect(TaskEditStatus.complete.raw, 'completed');
      expect(TaskEditStatus.reject.raw, 'rejected');
      expect(TaskEditStatus.cancel.raw, 'cancelled');
      for (final TaskEditStatus status in TaskEditStatus.values) {
        expect(TaskStatus.fromRaw(status.raw), status.status);
        expect(status.status.isOpen, isFalse);
      }
    });
  });

  group('the sheet is seeded from the row it was opened on', () {
    test('a row that names its work type and creator gives both up', () {
      final TaskItem row = TaskItem.fromRow(<String, Object?>{
        'id': 12,
        'work_type_id': 3,
        'work_type_name': 'Frontend',
        'created_by': 4,
        'creator_name': 'Məhəmməd Qasımov',
      }, TaskSource.internal);

      expect(row.workTypeId, 3);
      expect(row.assignedById, 4);
      expect(row.assignedBy, 'Məhəmməd Qasımov');
    });

    test('the single-task row fills in what no list row carries', () {
      final TaskEditSnapshot snapshot = TaskEditSnapshot.fromRow(
        <String, Object?>{
          'assigned_to': 7,
          'assigned_to_name': 'Əli Balakişiyev',
          'work_type_id': 3,
          'task_description': 'Sayt yenilənsin',
          'notes': 'Ödəniş sonra',
          'due_date': '2026-09-30',
          // Spelled as a string by one endpoint and as a bool by another.
          'is_company_viewable': 'false',
        },
      );

      expect(snapshot.assignedToId, 7);
      expect(snapshot.assignedToName, 'Əli Balakişiyev');
      expect(snapshot.workTypeId, 3);
      expect(snapshot.note, 'Ödəniş sonra');
      // `readDate` reads a zone-less string as UTC and localises it, so the
      // clock on a due date is whatever the device's offset makes it — the day
      // is the part this sheet writes back.
      expect(snapshot.dueDate?.year, 2026);
      expect(snapshot.dueDate?.month, 9);
      expect(snapshot.dueDate?.day, 30);
      expect(snapshot.showToCompany, isFalse);
    });
  });
}
