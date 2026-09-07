import 'package:flutter_test/flutter_test.dart';

import 'package:guven_mobile/src/features/tasks/domain/new_task.dart';

/// `/users/company/{code}` mixes two spellings of a person's name in one list
/// — an employee is `first_name`/`last_name`, a company owner is
/// `ceo_name`/`ceo_lastname` — and carries the email address alongside both.
/// Reading only half of them left every picker on the `Yeni tapşırıq` sheet
/// listing addresses.
void main() {
  group('an employee row reads as a name, not an address', () {
    test('an employee: first_name + last_name', () {
      expect(
        TaskOption.employee(<String, Object?>{
          'id': 7,
          'first_name': 'Əli',
          'last_name': 'Balakişiyev',
          'email': 'ali.balakishiyev1@gmail.com',
        })?.name,
        'Əli Balakişiyev',
      );
    });

    test('an owner: ceo_name + ceo_lastname', () {
      expect(
        TaskOption.employee(<String, Object?>{
          'id': 4,
          'ceo_name': 'Könül',
          'ceo_lastname': 'Əsədova',
          'email': 'konul.asadova@guvenfinans.az',
        })?.name,
        'Könül Əsədova',
      );
    });

    test('a surname the row never filled in is simply left off', () {
      expect(
        TaskOption.employee(<String, Object?>{
          'id': 9,
          'first_name': 'Nigar',
          'last_name': '',
          'email': 'zarbaliyevanigar17@gmail.com',
        })?.name,
        'Nigar',
      );
    });

    test('an already-joined full_name is taken as it comes', () {
      expect(
        TaskOption.employee(<String, Object?>{
          'id': 12,
          'full_name': 'Vüsal Əsədov',
          'email': 'vusal.asadov@guvenfinans.az',
        })?.name,
        'Vüsal Əsədov',
      );
    });

    test('a row that names nobody keeps its address rather than vanishing', () {
      // Two nameless accounts both labelled `Ad yoxdur` could not be told
      // apart, so the address stays as the last resort — never before a name.
      expect(
        TaskOption.employee(<String, Object?>{
          'id': 15,
          'email': 'sadat79@gmail.com',
        })?.name,
        'sadat79@gmail.com',
      );
    });

    test('a row with neither is dropped', () {
      expect(TaskOption.employee(<String, Object?>{'id': 21}), isNull);
    });
  });
}
