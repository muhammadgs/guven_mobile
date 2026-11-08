import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:guven_mobile/src/core/network/api_client.dart';
import 'package:guven_mobile/src/core/network/token_store.dart';
import 'package:guven_mobile/src/features/attendance/application/attendance_controller.dart';
import 'package:guven_mobile/src/features/attendance/data/attendance_api.dart';
import 'package:guven_mobile/src/features/attendance/domain/attendance.dart';
import 'package:guven_mobile/src/features/attendance/presentation/attendance_metrics.dart';
import 'package:guven_mobile/src/features/attendance/presentation/widgets/attendance_prompt.dart';

/// Davamiyyət: the site's rules, the backend's shapes as seen live on
/// 2026-11-08, the presses, the geometry on every phone, and the prompts'
/// conversation end to end.
void main() {
  group('rules (the site\'s, Baku time)', () {
    DateTime at(int h, int m) => DateTime(2026, 11, 9, h, m);

    test('09:00 sharp is on time, 09:01 is late', () {
      expect(AttendanceRules.isLateEntry(at(9, 0)), isFalse);
      expect(AttendanceRules.isLateEntry(at(9, 1)), isTrue);
      expect(AttendanceRules.isLateEntry(at(7, 30)), isFalse);
    });

    test('17:59 is early, 18:00 is not', () {
      expect(AttendanceRules.isEarlyExit(at(17, 59)), isTrue);
      expect(AttendanceRules.isEarlyExit(at(18, 0)), isFalse);
      expect(AttendanceRules.isEarlyExit(at(21, 0)), isFalse);
    });

    test('arriving early and leaving late are never asked about', () {
      expect(
        AttendanceRules.needsReason(AttendanceKind.entry, at(7, 0)),
        isFalse,
      );
      expect(
        AttendanceRules.needsReason(AttendanceKind.exit, at(20, 0)),
        isFalse,
      );
    });

    test('reminders are due from the hour on', () {
      expect(AttendanceRules.entryReminderDue(at(8, 59)), isFalse);
      expect(AttendanceRules.entryReminderDue(at(9, 0)), isTrue);
      expect(AttendanceRules.exitReminderDue(at(17, 59)), isFalse);
      expect(AttendanceRules.exitReminderDue(at(18, 0)), isTrue);
    });

    test('Baku is UTC+4 whatever the phone says', () {
      final DateTime baku = bakuTime(DateTime.utc(2026, 11, 8, 20, 30));
      expect(baku.day, 9);
      expect(baku.hour, 0);
      expect(attendanceDateKey(baku), '2026-11-09');
    });
  });

  group('shapes', () {
    test('notes pair with the newest logs when there are fewer of them', () {
      // Exactly what the live account answered.
      final AttendanceHistory history = AttendanceHistory.fromResponse(
        <String, Object?>{
          'success': true,
          'entry_logs': <String>['2026-08-31 11:37', '2026-11-08 14:29'],
          'exit_logs': <String>[],
          'entry_notes': <String>['Test'],
          'exit_notes': <String>[],
        },
      );
      expect(history.events.map((AttendanceEvent e) => e.stamp), <String>[
        '2026-11-08 14:29',
        '2026-08-31 11:37',
      ]);
      expect(history.events.first.note, 'Test');
      expect(history.events.last.note, isNull);
    });

    test('entries and exits interleave newest first', () {
      final AttendanceHistory history = AttendanceHistory.fromResponse(
        <String, Object?>{
          'data': <String, Object?>{
            'entry_logs': <String>['2026-11-07 09:30', '2026-11-08 08:50'],
            'exit_logs': <String>['2026-11-07 17:00'],
            'entry_notes': <String>['Yatıb qalmışam', ''],
            'exit_notes': <String>['İcazəli'],
          },
        },
      );
      expect(
        history.events.map((AttendanceEvent e) => '${e.kind.name} ${e.note}'),
        <String>['entry null', 'exit İcazəli', 'entry Yatıb qalmışam'],
      );
    });

    test('today reads the counts, the flags, and the history\'s', () {
      expect(
        AttendanceToday.fromResponse(<String, Object?>{
          'entries_today': <String>['2026-11-08 14:29'],
          'exits_today': <String>[],
        }).day,
        AttendanceDay.atWork,
      );
      expect(
        AttendanceToday.fromResponse(<String, Object?>{
          'has_entered_today': true,
          'has_exited_today': true,
        }).day,
        AttendanceDay.finished,
      );
      // `today-status` said nothing, the history knows better.
      final AttendanceHistory history = AttendanceHistory.fromResponse(
        <String, Object?>{
          'entry_logs': <String>['2026-11-08 08:55'],
        },
      );
      expect(
        AttendanceToday.fromResponse(
          <String, Object?>{},
        ).reconciledWith(history, '2026-11-08').day,
        AttendanceDay.atWork,
      );
    });
  });

  group('presses', () {
    test('check-in posts the note and the card turns to Çıxış', () async {
      final _Server server = _Server();
      final AttendanceController c = server.controller();
      await c.refresh();
      expect(c.day, AttendanceDay.notEntered);
      expect(c.nextKind, AttendanceKind.entry);

      expect(await c.press(AttendanceKind.entry, 'İcazəli'), isNull);
      expect(server.posts, <String>[
        '/api/v1/attendance/check-in {"note":"İcazəli"}',
      ]);
      expect(c.day, AttendanceDay.atWork);
      expect(c.nextKind, AttendanceKind.exit);
      expect(c.history.events.single.note, 'İcazəli');
    });

    test('a second check-in the same day is never sent', () async {
      final _Server server = _Server()..entries.add('2026-11-08 09:00');
      final AttendanceController c = server.controller();
      expect(await c.press(AttendanceKind.entry, ''), isNull);
      expect(server.posts, isEmpty);
      expect(c.day, AttendanceDay.atWork);
    });

    test('check-out before check-in is refused here', () async {
      final _Server server = _Server();
      final AttendanceController c = server.controller();
      expect(await c.press(AttendanceKind.exit, ''), isNotNull);
      expect(server.posts, isEmpty);
    });

    test('a server failure comes back as words, and nothing changes', () async {
      final _Server server = _Server()..failPosts = true;
      final AttendanceController c = server.controller();
      final String? error = await c.press(AttendanceKind.entry, '');
      expect(error, isNotNull);
      expect(c.day, AttendanceDay.notEntered);
      expect(c.isBusy, isFalse);
    });
  });

  group('geometry on every phone', () {
    const List<(String, Size, EdgeInsets)> phones =
        <(String, Size, EdgeInsets)>[
          (
            'iPhone 16 Pro',
            Size(402, 874),
            EdgeInsets.only(top: 62, bottom: 34),
          ),
          ('Galaxy S23', Size(360, 780), EdgeInsets.only(top: 36, bottom: 48)),
          ('S23 Ultra', Size(384, 824), EdgeInsets.only(top: 40, bottom: 24)),
          ('short 16:9', Size(360, 640), EdgeInsets.only(top: 24, bottom: 48)),
          ('small', Size(320, 568), EdgeInsets.only(top: 20)),
          ('iPad', Size(820, 1180), EdgeInsets.only(top: 24, bottom: 20)),
        ];

    for (final (String name, Size size, EdgeInsets pad) in phones) {
      for (final double text in <double>[1.0, 1.2]) {
        test('$name at text ×$text', () {
          final double scale =
              (size.shortestSide / 390).clamp(0.85, 1.6) * 390 / 402;
          final AttendanceMetrics m = AttendanceMetrics.raw(
            scale: scale,
            screen: size,
            padding: pad,
            textScaler: TextScaler.linear(text),
          );

          // The card fits across, from the button's left edge.
          expect(m.profileLeft + m.cardWidth, lessThanOrEqualTo(size.width));
          // Its buttons and the history panel fit inside it.
          expect(
            m.historyButtonLeft(withAction: true) + m.buttonWidth,
            lessThan(m.cardWidth),
          );
          expect(m.panelLeft + m.panelWidth, lessThan(m.cardWidth));
          // The status line ends above the buttons, at any text size.
          expect(
            m.statusTop + m.font(AttendanceMetrics.bodySize) * 1.4,
            lessThanOrEqualTo(m.buttonsTop + 0.5),
          );

          // A long history never pushes the card under the nav bar.
          final double reserve = pad.bottom + 90 * scale;
          final Rect button = Rect.fromLTWH(
            m.profileLeft,
            pad.top + 10,
            m.profileDiameter,
            m.profileDiameter,
          );
          final double cardTop = m.cardRectFor(button, 0).top;
          final double panel = m.panelHeight(
            List<bool>.filled(60, true),
            cardTop: cardTop,
            floor: m.cardFloor(reserve),
          );
          expect(
            cardTop + m.cardOpenHeight(panel),
            lessThanOrEqualTo(m.cardFloor(reserve) + 0.01),
          );

          // Every prompt fits on screen, and they all share a top edge.
          final double written = m.writtenPromptHeight;
          final Rect short = m.promptRect(m.messagePromptHeight(1));
          final Rect tall = m.promptRect(written);
          expect(tall.top, short.top);
          expect(tall.bottom, lessThanOrEqualTo(size.height));
          expect(short.left, greaterThan(0));

          // With the keyboard up, the reason box is lifted clear of it.
          final AttendanceMetrics typing = AttendanceMetrics.raw(
            scale: scale,
            screen: size,
            padding: pad,
            keyboard: size.height * 0.4,
            textScaler: TextScaler.linear(text),
          );
          final Rect lifted = typing.promptRect(written);
          if (lifted.top > pad.top + 8 * scale + 0.01) {
            expect(lifted.bottom, lessThanOrEqualTo(size.height * 0.6 + 0.01));
          }
        });
      }
    }
  });

  group('the prompt', () {
    testWidgets('late: Yazılı bildir → Ləğv et → not recorded → Sonra', (
      WidgetTester tester,
    ) async {
      final _Server server = _Server();
      final AttendanceController c = server.controller(
        now: DateTime.utc(2026, 11, 8, 6, 15), // 10:15 in Baku
      );
      await c.refresh();
      await _open(tester, c, PromptStage.reminder);

      expect(find.text('Bu gün hələ giriş etməmisiniz'), findsOneWidget);
      await tester.tap(find.text('Giriş'));
      await tester.pumpAndSettle();

      expect(find.text('Girişdə gecikmə!'), findsOneWidget);
      expect(find.text('09:00-dan gec gəlmisiniz.'), findsOneWidget);
      await tester.tap(find.text('Yazılı bildir'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      await tester.tap(find.text('Ləğv et'));
      await tester.pumpAndSettle();

      expect(find.text('Girişiniz qeyd olunmadı.'), findsOneWidget);
      expect(server.posts, isEmpty);
      await tester.tap(find.text('Sonra'));
      await tester.pumpAndSettle();
      expect(find.byType(AttendancePrompt), findsNothing);
      expect(server.posts, isEmpty);
    });

    testWidgets('a written reason is sent as the note', (
      WidgetTester tester,
    ) async {
      final _Server server = _Server();
      final AttendanceController c = server.controller(
        now: DateTime.utc(2026, 11, 8, 6, 15),
      );
      await c.refresh();
      await _open(tester, c, PromptStage.reason);

      await tester.tap(find.text('Yazılı bildir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Tıxac idi');
      await tester.pump();
      await tester.tap(find.text('Bildir'));
      await tester.pumpAndSettle();

      expect(server.posts, <String>[
        '/api/v1/attendance/check-in {"note":"Tıxac idi"}',
      ]);
      expect(find.byType(AttendancePrompt), findsNothing);
      expect(c.day, AttendanceDay.atWork);
    });

    testWidgets('early exit: İcazəli files the site\'s note', (
      WidgetTester tester,
    ) async {
      final _Server server = _Server()..entries.add('2026-11-08 08:58');
      final AttendanceController c = server.controller(
        now: DateTime.utc(2026, 11, 8, 12, 40), // 16:40 in Baku
      );
      await c.refresh();
      await _open(tester, c, PromptStage.reason, kind: AttendanceKind.exit);

      expect(find.text('Erkən çıxış!'), findsOneWidget);
      expect(find.text('18:00-dan tez çıxırsınız.'), findsOneWidget);
      await tester.tap(find.text('İcazəli'));
      await tester.pumpAndSettle();

      expect(server.posts, <String>[
        '/api/v1/attendance/check-out {"note":"İcazəli"}',
      ]);
      expect(c.day, AttendanceDay.finished);
    });

    testWidgets('a tap off the question is not an answer', (
      WidgetTester tester,
    ) async {
      final _Server server = _Server();
      final AttendanceController c = server.controller(
        now: DateTime.utc(2026, 11, 8, 6, 15),
      );
      await c.refresh();
      await _open(tester, c, PromptStage.reason);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Girişiniz qeyd olunmadı.'), findsOneWidget);

      // …and its Giriş asks again, because it is still late.
      await tester.tap(find.text('Giriş'));
      await tester.pumpAndSettle();
      expect(find.text('Girişdə gecikmə!'), findsOneWidget);
    });

    testWidgets('on time, the reminder\'s Giriş just checks in', (
      WidgetTester tester,
    ) async {
      final _Server server = _Server();
      final AttendanceController c = server.controller(
        now: DateTime.utc(2026, 11, 8, 5, 0), // 09:00 sharp in Baku
      );
      await c.refresh();
      await _open(tester, c, PromptStage.reminder);

      await tester.tap(find.text('Giriş'));
      await tester.pumpAndSettle();
      expect(server.posts, <String>['/api/v1/attendance/check-in {"note":""}']);
      expect(find.byType(AttendancePrompt), findsNothing);
    });
  });
}

Future<void> _open(
  WidgetTester tester,
  AttendanceController c,
  PromptStage stage, {
  AttendanceKind kind = AttendanceKind.entry,
}) async {
  tester.view.physicalSize = const Size(1206, 2622);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (BuildContext context) => Center(
          child: TextButton(
            onPressed: () => showAttendancePrompt(
              context,
              controller: c,
              kind: kind,
              start: stage,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// The four routes, in memory, answering the way the live server does.
class _Server {
  final List<String> entries = <String>[];
  final List<String> exits = <String>[];
  final List<String> entryNotes = <String>[];
  final List<String> exitNotes = <String>[];
  final List<String> posts = <String>[];
  bool failPosts = false;

  static const String today = '2026-11-08';

  AttendanceController controller({DateTime? now}) {
    final MockClient transport = MockClient((http.Request request) async {
      final String path = request.url.path;
      Map<String, Object?> body;
      int status = 200;
      if (request.method == 'POST') {
        if (failPosts) {
          return http.Response(
            jsonEncode(<String, Object?>{'detail': 'Server xətası'}),
            500,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        posts.add('$path ${request.body}');
        final String note =
            (jsonDecode(request.body) as Map<String, Object?>)['note']!
                as String;
        if (path.endsWith('check-in')) {
          entries.add('$today 10:15');
          entryNotes.add(note);
        } else {
          exits.add('$today 16:40');
          exitNotes.add(note);
        }
        body = <String, Object?>{'success': true, 'timestamp': '$today 10:15'};
      } else if (path.endsWith('today-status')) {
        body = <String, Object?>{
          'entries_today': entries
              .where((String e) => e.startsWith(today))
              .toList(),
          'exits_today': exits
              .where((String e) => e.startsWith(today))
              .toList(),
        };
      } else {
        body = <String, Object?>{
          'entry_logs': entries,
          'exit_logs': exits,
          'entry_notes': entryNotes,
          'exit_notes': exitNotes,
        };
      }
      return http.Response(
        jsonEncode(body),
        status,
        headers: <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      );
    });
    return AttendanceController(
      AttendanceApi(ApiClient(tokens: TokenStore(), httpClient: transport)),
      now: () => now ?? DateTime.utc(2026, 11, 8, 6, 15),
    );
  }
}
