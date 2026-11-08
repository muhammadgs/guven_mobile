import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/attendance_api.dart';
import '../domain/attendance.dart';

/// Where the first answer is.
enum AttendanceLoad { loading, ready, failed }

/// Today's attendance and its history, and the two presses that change them.
///
/// Owned by the home screen and handed to the profile card and to every
/// prompt, so all three show the same day — press `Giriş` in a prompt and
/// the card behind it turns to `Çıxış` in the same frame.
class AttendanceController extends ChangeNotifier {
  AttendanceController(this._api, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AttendanceApi _api;
  final DateTime Function() _now;

  AttendanceLoad _load = AttendanceLoad.loading;
  AttendanceLoad get load => _load;

  AttendanceDay _day = AttendanceDay.notEntered;
  AttendanceDay get day => _day;

  AttendanceHistory _history = AttendanceHistory.empty;
  AttendanceHistory get history => _history;

  /// The button whose request is in flight, so it alone shows a spinner and
  /// a second tap on anything is ignored.
  AttendanceKind? _pressing;
  AttendanceKind? get pressing => _pressing;
  bool get isBusy => _pressing != null;

  bool _refreshing = false;
  bool _disposed = false;

  /// Now, on Baku's clock.
  DateTime get baku => bakuTime(_now());

  /// The button today calls for, or null once both have been pressed.
  AttendanceKind? get nextKind => switch (_day) {
    AttendanceDay.notEntered => AttendanceKind.entry,
    AttendanceDay.atWork => AttendanceKind.exit,
    AttendanceDay.finished => null,
  };

  /// Re-reads today and the history together. True when both answered.
  ///
  /// A failure after a good load keeps what is on screen — a dropped request
  /// should not wipe out a history that was right a minute ago.
  Future<bool> refresh() async {
    if (_refreshing) return _load == AttendanceLoad.ready;
    _refreshing = true;
    try {
      final (AttendanceToday today, AttendanceHistory history) = await (
        _api.today(),
        _api.history(),
      ).wait;
      _history = history;
      _day = today.reconciledWith(history, attendanceDateKey(baku)).day;
      _load = AttendanceLoad.ready;
      return true;
    } on ParallelWaitError<dynamic, dynamic> {
      if (_load != AttendanceLoad.ready) _load = AttendanceLoad.failed;
      return false;
    } on ApiException {
      if (_load != AttendanceLoad.ready) _load = AttendanceLoad.failed;
      return false;
    } finally {
      _refreshing = false;
      _notify();
    }
  }

  /// Presses [kind] with [note]. Null on success, otherwise what went wrong,
  /// in Azerbaijani.
  ///
  /// Today is re-read first, as the site does: the person may have pressed
  /// the same button on the website since this screen last looked, and the
  /// server does not refuse a second entry on the same day.
  Future<String?> press(AttendanceKind kind, String note) async {
    if (_pressing != null) return null;
    _pressing = kind;
    _notify();
    try {
      if (!await refresh()) {
        return 'Bu günkü status yoxlanıla bilmədi. Bir az sonra yenidən cəhd edin.';
      }
      switch (kind) {
        case AttendanceKind.entry:
          // Already in: nothing to do, and the card already says so.
          if (_day != AttendanceDay.notEntered) return null;
          await _api.checkIn(note);
        case AttendanceKind.exit:
          if (_day == AttendanceDay.notEntered) {
            return 'Bu gün hələ giriş etməmisiniz.';
          }
          if (_day == AttendanceDay.finished) return null;
          await _api.checkOut(note);
      }
      // Optimistic, then confirmed: the card turns the moment the server
      // says yes, and the history fills in when the re-read lands.
      _day = kind == AttendanceKind.entry
          ? AttendanceDay.atWork
          : AttendanceDay.finished;
      _notify();
      await refresh();
      return null;
    } on ApiException catch (error) {
      return error.isOffline ? 'İnternet bağlantısı yoxdur.' : error.message;
    } finally {
      _pressing = null;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
