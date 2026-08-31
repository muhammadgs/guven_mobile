import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/task_files_api.dart';
import '../domain/task_attachment.dart';

/// Plays the voice notes hanging off task cards.
///
/// **One** player for the whole screen, not one per card. That is how a chat
/// app behaves — starting a second recording stops the first — and it is also
/// the only way a list of cards does not end up holding a dozen platform
/// players open at once.
///
/// The file has to be on disk before it can be played, so the first tap on a
/// note downloads it through [TaskFilesApi] (which caches it for the session)
/// and the ones after that start immediately.
class TaskVoicePlayer extends ChangeNotifier {
  TaskVoicePlayer(this._files, {AudioPlayer? player}) : _injected = player;

  final TaskFilesApi _files;

  final AudioPlayer? _injected;

  /// Built on the first tap, not when this controller is.
  ///
  /// `AudioPlayer`'s constructor reaches straight for the platform, and this
  /// player is created for every task list whether or not any task on it has a
  /// recording. Deferring it means a screen with no voice notes — and a widget
  /// test of one — never opens a native player at all.
  late final AudioPlayer _player = _injected ?? AudioPlayer();
  bool _opened = false;

  /// Whether the platform player is running, tracked here rather than read off
  /// [AudioPlayer.state]: asking it would build one.
  bool _running = false;

  StreamSubscription<Duration>? _positions;
  StreamSubscription<Duration>? _durations;
  StreamSubscription<void>? _completions;

  /// The note the player is on, playing or paused.
  String? _current;
  String? get current => _current;

  /// The note being fetched right now, if any.
  String? _fetching;

  Duration _position = Duration.zero;
  Duration _length = Duration.zero;

  /// The last failure, and which note it belongs to.
  String? _failure;
  String? _failedId;

  bool _disposed = false;

  bool isPlaying(String id) => _current == id && _running;

  bool isLoading(String id) => _fetching == id;

  /// How far through [id] playback has got, 0…1. Zero for every other note,
  /// so only one wave on the screen is ever filled in.
  double progressOf(String id) {
    if (_current != id || _length.inMilliseconds <= 0) return 0;
    return (_position.inMilliseconds / _length.inMilliseconds).clamp(0.0, 1.0);
  }

  /// What the clock beside [id] shows: how far in, while it is the one
  /// playing, and how long it is once that is known.
  Duration clockFor(String id) =>
      _current == id && _position > Duration.zero ? _position : _length;

  /// True when [id] is the note whose length is actually known. A note that has
  /// never been played has no duration until it has been opened once.
  bool hasClock(String id) => _current == id && _length > Duration.zero;

  String? failureFor(String id) => _failedId == id ? _failure : null;

  /// Starts, pauses or resumes [file].
  Future<void> toggle(TaskAttachment file) async {
    if (_fetching != null) return;

    if (_current == file.id) {
      if (_running) {
        await _player.pause();
        _running = false;
      } else {
        await _player.resume();
        _running = true;
      }
      _notify();
      return;
    }

    _fetching = file.id;
    _failure = null;
    _failedId = null;
    _notify();

    try {
      final String path = await _files.localPath(file);
      if (!File(path).existsSync()) throw const ApiException('Fayl yoxdur.');

      _opened = true;
      await _player.stop();
      _listen();
      _current = file.id;
      _position = Duration.zero;
      _length = Duration.zero;
      await _player.play(DeviceFileSource(path));
      _running = true;
    } on ApiException catch (error) {
      _failure = error.message;
      _failedId = file.id;
      _current = null;
      _running = false;
    } catch (_) {
      _failure = 'Səs qeydi açılmadı.';
      _failedId = file.id;
      _current = null;
      _running = false;
    } finally {
      _fetching = null;
      _notify();
    }
  }

  void _listen() {
    _positions ??= _player.onPositionChanged.listen((Duration value) {
      _position = value;
      _notify();
    });
    _durations ??= _player.onDurationChanged.listen((Duration value) {
      _length = value;
      _notify();
    });
    _completions ??= _player.onPlayerComplete.listen((_) {
      _position = Duration.zero;
      _running = false;
      _notify();
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_positions?.cancel());
    unawaited(_durations?.cancel());
    unawaited(_completions?.cancel());
    if (_opened) unawaited(_player.dispose());
    super.dispose();
  }
}
