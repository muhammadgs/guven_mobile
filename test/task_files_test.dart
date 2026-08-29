import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/tasks/data/tasks_api.dart';
import 'package:guven_mobile/src/features/tasks/domain/task_attachment.dart';
import 'package:guven_mobile/src/features/tasks/domain/task_item.dart';
import 'package:guven_mobile/src/features/tasks/domain/task_scope.dart';
import 'package:guven_mobile/src/features/tasks/domain/task_status.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const String _uuidA = '3f2504e0-4f89-11d3-9a0c-0305e82c3301';
const String _uuidB = '9c858901-8a57-4791-81fe-4c455b099bc9';

void main() {
  group('file uuids', () {
    test('reads the PostgreSQL array literal the backend sends', () {
      // `uuid[]` comes back through the API as its own text form on several
      // endpoints, quotes and braces included.
      expect(parseFileUuids('{"$_uuidA","$_uuidB"}'), <String>[
        _uuidA,
        _uuidB,
      ]);
    });

    test('reads a real JSON array too', () {
      expect(parseFileUuids(<String>[_uuidA]), <String>[_uuidA]);
    });

    test('drops an empty column and anything that is not a uuid', () {
      expect(parseFileUuids('{}'), isEmpty);
      expect(parseFileUuids(''), isEmpty);
      expect(parseFileUuids(null), isEmpty);
      expect(parseFileUuids('{NULL,"not-a-uuid"}'), isEmpty);
    });
  });

  group('file types', () {
    test('a real mime type decides', () {
      expect(
        AttachmentKind.resolve(mimeType: 'application/pdf'),
        AttachmentKind.pdf,
      );
      expect(
        AttachmentKind.resolve(
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
        AttachmentKind.excel,
      );
    });

    test('octet-stream is the server declining to say, so the name decides', () {
      expect(
        AttachmentKind.resolve(
          mimeType: 'application/octet-stream',
          filename: 'müqavilə.docx',
        ),
        AttachmentKind.word,
      );
    });

    test('a recording is a recording whatever it was encoded as', () {
      expect(
        AttachmentKind.resolve(mimeType: 'audio/webm', isVoiceNote: true),
        AttachmentKind.voiceNote,
      );
      // …and audio without that marker is an ordinary audio file.
      expect(
        AttachmentKind.resolve(mimeType: 'audio/mpeg'),
        AttachmentKind.music,
      );
    });

    test('an unknown file is still a file', () {
      expect(AttachmentKind.resolve(filename: 'data.bin'), AttachmentKind.other);
    });
  });

  group('a task row', () {
    test('names its files as ids that still need describing', () {
      final TaskItem task = TaskItem.fromRow(<String, Object?>{
        'id': 4,
        'file_uuids': '{"$_uuidA"}',
      }, TaskSource.internal);

      expect(task.hasAttachments, isTrue);
      expect(task.needsFileDetails, isTrue);
      expect(task.attachments.single.id, _uuidA);
    });

    test('takes an embedded file object as already described', () {
      final TaskItem task = TaskItem.fromRow(<String, Object?>{
        'id': 4,
        'attachments': jsonEncode(<Map<String, Object?>>[
          <String, Object?>{
            'id': _uuidB,
            'original_filename': 'hesabat.xlsx',
            'mime_type': 'application/vnd.ms-excel',
          },
        ]),
      }, TaskSource.internal);

      expect(task.needsFileDetails, isFalse);
      expect(task.attachments.single.kind, AttachmentKind.excel);
      expect(task.attachments.single.label, 'EXCEL faylı');
    });
  });

  group('a saved file gets an extension when the server gave none', () {
    test('from the mime type', () {
      const TaskAttachment file = TaskAttachment(
        id: _uuidA,
        mimeType: 'application/pdf',
      );
      expect(file.suggestedExtension, 'pdf');
    });

    test('from the type when even that is missing', () {
      const TaskAttachment file = TaskAttachment(
        id: _uuidA,
        kind: AttachmentKind.excel,
      );
      expect(file.suggestedExtension, 'xlsx');
    });

    test('and not at all when the name already has one', () {
      const TaskAttachment file = TaskAttachment(
        id: _uuidA,
        name: 'hesabat.xlsx',
        kind: AttachmentKind.excel,
      );
      expect(file.suggestedExtension, isNull);
    });
  });

  group('the live lists', () {
    late List<Uri> requested;
    late TasksApi api;

    setUp(() {
      requested = <Uri>[];
      final MockClient transport = MockClient((http.Request request) async {
        requested.add(request.url);
        return http.Response(
          jsonEncode(<Map<String, Object?>>[
            _row(1, 'in_progress'),
            _row(2, 'completed'),
            _row(3, 'cancelled'),
            _row(4, 'rejected'),
            _row(5, 'archived'),
          ]),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      api = TasksApi(ApiClient(tokens: TokenStore(), httpClient: transport));
    });

    test('keep refusals but drop finished and cancelled work', () async {
      // All three, not only Daxili: finished work belongs to Arxiv wherever
      // it came from.
      for (final TaskScope scope in <TaskScope>[
        TaskScope.internal,
        TaskScope.company,
        TaskScope.partner,
      ]) {
        expect(
          (await api.load(scope)).map((TaskItem task) => task.status),
          <TaskStatus>[TaskStatus.rejected, TaskStatus.inProgress],
          reason: '$scope still shows finished work',
        );
      }
    });

    test('Arxiv, on the other hand, keeps everything', () async {
      expect((await api.load(TaskScope.archive)).length, 5);
    });

    test('asks the server for the open statuses in the first place', () async {
      await api.load(TaskScope.internal);

      final String status = requested.single.queryParameters['status']!;
      expect(status, contains('rejected'));
      expect(status, isNot(contains('completed')));
      expect(status, isNot(contains('cancelled')));
    });
  });

  test('Hesabat asks for nothing at all', () async {
    bool called = false;
    final MockClient transport = MockClient((http.Request request) async {
      called = true;
      return http.Response('[]', 200);
    });
    final TasksApi api = TasksApi(
      ApiClient(tokens: TokenStore(), httpClient: transport),
    );

    expect(await api.load(TaskScope.report), isEmpty);
    expect(called, isFalse);
  });
}

Map<String, Object?> _row(int id, String status) => <String, Object?>{
  'id': id,
  'status': status,
  'company_name': 'Güvən Finans MMC',
  'work_type_name': 'Frontend Developer',
  // Ordered by creation date, newest first — id 4 is the most recent of the
  // two that survive the filter.
  'created_at': '2026-08-0${id}T10:00:00',
};
