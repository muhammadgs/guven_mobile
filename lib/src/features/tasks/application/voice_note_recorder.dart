import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../domain/new_task.dart';

/// What the `Səs qeydi` field is doing right now.
enum VoiceStage {
  /// Nothing recorded yet — only the microphone is on screen.
  idle,

  /// The microphone is live and the wave is being drawn from it.
  recording,

  /// Recording is held. The take can be listened to, thrown away, added, or
  /// carried on with.
  paused,

  /// Playing the take back before it has been added.
  playing,
}

/// One recording, as far as the sheet is concerned.
///
/// [open] is the part worth knowing about: a note that is still open has a
/// live recorder session behind it, merely paused, which is what makes
/// `mikrofon` on an already-added note *continue* it rather than start a
/// second one. Closing it is one-way — AAC frames cannot be spliced on the
/// phone — so the newest note is the only one that can ever be open.
class VoiceNote {
  VoiceNote({
    required this.path,
    required this.envelope,
    required this.duration,
    this.open = true,
  });

  String path;

  /// One loudness sample per [VoiceNoteRecorder.sampleInterval], 0…1. This is
  /// the only record of what the recording *looked* like — nothing decodes the
  /// file afterwards to work it out again.
  List<double> envelope;

  Duration duration;
  bool open;

  /// The name the file is uploaded under.
  ///
  /// `ses-qeydi` is not decoration: both clients decide a file is a voice note
  /// rather than an audio file by looking for exactly that in the name, and
  /// the website's uploader does the same.
  String get filename =>
      'ses-qeydi-${DateTime.now().millisecondsSinceEpoch}.m4a';
}

/// Drives the microphone, the waveform behind it, and the preview player.
///
/// Owns three things that have to agree with each other: the recorder, a
/// stopwatch (the recorder does not report elapsed time, and counting
/// amplitude callbacks drifts), and a player for listening back before the
/// note is added.
class VoiceNoteRecorder extends ChangeNotifier {
  VoiceNoteRecorder({AudioRecorder? recorder, AudioPlayer? player})
    : _injectedRecorder = recorder,
      _injectedPlayer = player;

  final AudioRecorder? _injectedRecorder;
  final AudioPlayer? _injectedPlayer;

  /// Both are built on the first tap rather than when the sheet opens.
  ///
  /// Each constructor reaches straight for the platform, and most tasks are
  /// created without a recording — there is no reason to open a microphone
  /// session for a form nobody records into, and it is what lets a widget test
  /// of this sheet run without either plugin.
  late final AudioRecorder _recorder = _injectedRecorder ?? AudioRecorder();
  late final AudioPlayer _player = _injectedPlayer ?? AudioPlayer();
  bool _recorderOpened = false;
  bool _playerOpened = false;

  /// How often the level is sampled. Fine enough that a spoken syllable makes
  /// its own bar, coarse enough that a two-minute note is a few thousand
  /// doubles rather than tens of thousands.
  static const Duration sampleInterval = Duration(milliseconds: 60);

  /// dBFS at or below which the bar is drawn at its minimum height. Phone
  /// microphones idle around −50 dBFS in a quiet room; anchoring the floor
  /// there is what keeps silence flat instead of fuzzy.
  static const double _silenceFloor = -45;


  StreamSubscription<Amplitude>? _levels;
  StreamSubscription<Duration>? _positions;
  StreamSubscription<void>? _completions;
  final Stopwatch _clock = Stopwatch();
  Timer? _tick;

  VoiceStage _stage = VoiceStage.idle;
  VoiceStage get stage => _stage;

  /// The take being recorded or auditioned, before it is added to the task.
  VoiceNote? _draft;
  VoiceNote? get draft => _draft;

  /// The notes already added to the task.
  final List<VoiceNote> _notes = <VoiceNote>[];
  List<VoiceNote> get notes => List<VoiceNote>.unmodifiable(_notes);

  /// The note being played from the added list, if any.
  VoiceNote? _playingNote;
  VoiceNote? get playingNote => _playingNote;

  Duration _position = Duration.zero;

  /// How far playback has got, or how long the recording has run — whichever
  /// the field is currently showing.
  Duration get elapsed => switch (_stage) {
    VoiceStage.recording => _clockOffset + _clock.elapsed,
    VoiceStage.paused => _draft?.duration ?? Duration.zero,
    VoiceStage.playing => _position,
    VoiceStage.idle => _playingNote == null ? Duration.zero : _position,
  };

  /// Set when the microphone was refused, so the field can say so instead of
  /// silently doing nothing.
  String? _failure;
  String? get failure => _failure;

  bool _disposed = false;

  /// True while anything at all has been recorded — the sheet asks before it
  /// throws the recorder away.
  bool get hasAnything => _draft != null || _notes.isNotEmpty;

  // ── Recording ───────────────────────────────────────────────────────────

  /// Starts a new take.
  ///
  /// Any note still open is closed first: two live recorder sessions cannot
  /// exist at once, and the older one's file has to be finalised before its
  /// bytes can be read.
  Future<void> start() async {
    if (_stage == VoiceStage.recording) return;
    _failure = null;

    await _stopPlayback();
    await _closeOpenSessions();

    _recorderOpened = true;
    if (!await _recorder.hasPermission()) {
      _failure = 'Mikrofona icazə verilmədi.';
      _notify();
      return;
    }

    try {
      final Directory folder = Directory(
        '${(await getTemporaryDirectory()).path}/voice_notes',
      );
      await folder.create(recursive: true);
      final String path =
          '${folder.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        // AAC in an MP4 container: the one encoder every Android and iOS
        // device has, and one a browser can play back on the website without
        // being asked to.
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          numChannels: 1,
          bitRate: 96000,
        ),
        path: path,
      );

      _draft = VoiceNote(
        path: path,
        envelope: <double>[],
        duration: Duration.zero,
      );
      _clockOffset = Duration.zero;
      _clock
        ..reset()
        ..start();
      _listenToLevels();
      _startTicking();
      _stage = VoiceStage.recording;
      _notify();
    } catch (_) {
      _failure = 'Səs yazıla bilmədi.';
      _stage = VoiceStage.idle;
      _notify();
    }
  }

  /// Holds the take. The file stays open, so [resume] carries on into it.
  Future<void> pause() async {
    if (_stage != VoiceStage.recording) return;
    await _recorder.pause();
    _clock.stop();
    _stopTicking();
    _draft?.duration = _clockOffset + _clock.elapsed;
    _stage = VoiceStage.paused;
    _notify();
  }

  /// Carries on into the take — from the field, or from an added note whose
  /// session is still open.
  Future<void> resume([VoiceNote? note]) async {
    await _stopPlayback();

    if (note != null && note != _draft) {
      if (!note.open) return;
      // The note comes back up into the field, where the pause/send controls
      // live, exactly as it was left.
      _notes.remove(note);
      _draft = note;
      _clock
        ..reset()
        ..start();
      _clockOffset = note.duration;
    } else if (_draft == null) {
      return start();
    } else {
      _clockOffset = _draft!.duration;
      _clock
        ..reset()
        ..start();
    }

    await _recorder.resume();
    _listenToLevels();
    _startTicking();
    _stage = VoiceStage.recording;
    _notify();
  }

  /// How much of the current take was recorded before this stretch of it.
  Duration _clockOffset = Duration.zero;

  /// Throws the take away, whether it is in the field or already added.
  Future<void> discard([VoiceNote? note]) async {
    await _stopPlayback();

    final VoiceNote? target = note ?? _draft;
    if (target == null) return;

    if (target == _draft) {
      _stopTicking();
      _clock.stop();
      if (_stage == VoiceStage.recording || _stage == VoiceStage.paused) {
        try {
          await _recorder.cancel();
        } catch (_) {
          // Nothing to cancel — the session had already ended.
        }
      }
      _draft = null;
      _stage = VoiceStage.idle;
    } else {
      if (target.open) await _finalise(target);
      _notes.remove(target);
    }
    _delete(target.path);
    _clockOffset = Duration.zero;
    _notify();
  }

  /// Adds the take to the task.
  ///
  /// The recorder session is deliberately left alive and paused: that is what
  /// lets `mikrofon` on the added note pick the same recording back up, which
  /// AAC gives no other way of doing.
  Future<void> commit() async {
    if (_draft == null) return;
    if (_stage == VoiceStage.recording) await pause();
    await _stopPlayback();

    _draft!.duration = _clockOffset + _clock.elapsed;
    _notes.add(_draft!);
    _draft = null;
    _clockOffset = Duration.zero;
    _stage = VoiceStage.idle;
    _notify();
  }

  // ── Listening back ──────────────────────────────────────────────────────

  /// Plays the take in the field, or one of the added notes.
  Future<void> play([VoiceNote? note]) async {
    final VoiceNote? target = note ?? _draft;
    if (target == null) return;

    // A note that is still being recorded into has no readable file yet.
    if (target.open) await _finalise(target);
    if (!File(target.path).existsSync()) return;

    _playerOpened = true;
    await _player.stop();
    _positions ??= _player.onPositionChanged.listen(_onPosition);
    _completions ??= _player.onPlayerComplete.listen((_) => _onComplete());

    _position = Duration.zero;
    _playingNote = note == null ? null : target;
    if (note == null) _stage = VoiceStage.playing;
    _notify();

    await _player.play(DeviceFileSource(target.path));
  }

  /// Pauses playback, keeping the position so the next tap carries on.
  Future<void> pausePlayback() async {
    if (!_playerOpened || _player.state != PlayerState.playing) return;
    await _player.pause();
    if (_stage == VoiceStage.playing) _stage = VoiceStage.paused;
    _paused = true;
    _notify();
  }

  bool _paused = false;

  /// Whether [note] — or the take, when null — is the one being played.
  bool isPlaying(VoiceNote? note) {
    if (!_playerOpened || _player.state != PlayerState.playing) return false;
    return note == null ? _stage == VoiceStage.playing : _playingNote == note;
  }

  /// Resumes a paused playback, or starts one.
  Future<void> togglePlayback([VoiceNote? note]) async {
    if (isPlaying(note)) return pausePlayback();
    final bool sameSource = note == null
        ? _stage == VoiceStage.paused && _playingNote == null && _paused
        : _playingNote == note && _paused;
    if (sameSource) {
      _paused = false;
      if (note == null) _stage = VoiceStage.playing;
      _notify();
      await _player.resume();
      return;
    }
    _paused = false;
    await play(note);
  }

  /// How far through [note] playback is, 0…1. Drives the filled part of the
  /// wave, the way a voice note in a chat app fills as it plays.
  double progressOf(VoiceNote? note) {
    final bool mine = note == null
        ? (_stage == VoiceStage.playing || (_paused && _playingNote == null))
        : _playingNote == note;
    if (!mine) return 0;
    final VoiceNote? target = note ?? _draft;
    final int total = target?.duration.inMilliseconds ?? 0;
    if (total <= 0) return 0;
    return (_position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  // ── Handing the recordings over ─────────────────────────────────────────

  /// Everything recorded, ready to upload. Closes any session still open.
  Future<List<PendingUpload>> collect() async {
    if (_draft != null) await commit();
    final List<PendingUpload> uploads = <PendingUpload>[];
    for (final VoiceNote note in _notes) {
      if (note.open) await _finalise(note);
      final File file = File(note.path);
      if (!file.existsSync()) continue;
      uploads.add(
        PendingUpload(
          name: note.filename,
          bytes: await file.readAsBytes(),
          mimeType: 'audio/mp4',
          isVoiceNote: true,
          duration: note.duration,
        ),
      );
    }
    return uploads;
  }

  // ── Plumbing ────────────────────────────────────────────────────────────

  void _listenToLevels() {
    _levels ??= _recorder
        .onAmplitudeChanged(sampleInterval)
        .listen(_onLevel, onError: (Object _) {});
  }

  void _onLevel(Amplitude level) {
    if (_stage != VoiceStage.recording || _draft == null) return;
    final double db = level.current;
    final double unit = db.isFinite
        ? ((db - _silenceFloor) / -_silenceFloor).clamp(0.0, 1.0)
        : 0.0;
    // The ear is logarithmic and the eye is not: raising the normalised level
    // to a power below one lifts ordinary speech off the floor without
    // flattening a shout into the same bar.
    _draft!.envelope.add(math.pow(unit, 0.65).toDouble());
  }

  /// Redraws the elapsed time between level samples, so the clock moves at a
  /// steady rate rather than at whatever rate the platform answers.
  void _startTicking() {
    _tick ??= Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_stage == VoiceStage.recording) _notify();
    });
  }

  void _stopTicking() {
    _tick?.cancel();
    _tick = null;
  }

  void _onPosition(Duration position) {
    _position = position;
    _notify();
  }

  void _onComplete() {
    _position = Duration.zero;
    _paused = false;
    _playingNote = null;
    if (_stage == VoiceStage.playing) _stage = VoiceStage.paused;
    _notify();
  }

  Future<void> _stopPlayback() async {
    if (!_playerOpened || _player.state == PlayerState.stopped) return;
    await _player.stop();
    _position = Duration.zero;
    _paused = false;
    _playingNote = null;
    if (_stage == VoiceStage.playing) _stage = VoiceStage.paused;
  }

  /// Ends [note]'s recorder session so its file can be read.
  Future<void> _finalise(VoiceNote note) async {
    note.open = false;
    if (note == _draft) {
      _clock.stop();
      _stopTicking();
      note.duration = _clockOffset + _clock.elapsed;
    }
    try {
      final String? path = await _recorder.stop();
      if (path != null && path.isNotEmpty) note.path = path;
    } catch (_) {
      // Already stopped.
    }
    await _levels?.cancel();
    _levels = null;
  }

  Future<void> _closeOpenSessions() async {
    for (final VoiceNote note in <VoiceNote>[..._notes, ?_draft]) {
      if (note.open) await _finalise(note);
    }
  }

  void _delete(String path) {
    try {
      final File file = File(path);
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // A file the system has already cleaned out of the cache.
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTicking();
    unawaited(_levels?.cancel());
    unawaited(_positions?.cancel());
    unawaited(_completions?.cancel());
    if (_playerOpened) unawaited(_player.dispose());
    if (_recorderOpened) unawaited(_recorder.dispose());
    super.dispose();
  }
}
