import '../../../core/json.dart';
import '../../../core/network/api_client.dart';
import '../domain/attendance.dart';

/// The four attendance calls, exactly as the website makes them.
///
/// `POST` bodies are `{note}` and nothing else — an empty string when no
/// reason was asked for, which is what the site sends too.
class AttendanceApi {
  const AttendanceApi(this._client);

  final ApiClient _client;

  Future<AttendanceToday> today() async => AttendanceToday.fromResponse(
    await _client.get('/attendance/today-status'),
  );

  Future<AttendanceHistory> history() async =>
      AttendanceHistory.fromResponse(await _client.get('/attendance/history'));

  /// Returns the stamp the server filed, when it says.
  Future<String?> checkIn(String note) => _press('/attendance/check-in', note);

  Future<String?> checkOut(String note) =>
      _press('/attendance/check-out', note);

  Future<String?> _press(String endpoint, String note) async {
    final Object? reply = await _client.post(
      endpoint,
      body: <String, Object?>{'note': note},
    );
    return readString(asMap(reply), <String>['timestamp']);
  }
}
