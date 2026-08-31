import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'task_glass.dart';

/// The bars behind a voice note.
///
/// Three jobs, one drawing:
///
/// * **While recording** it shows the tail of the level trace, so the bars
///   move with the voice and scroll off to the left the way a chat app's do.
/// * **Once stopped** it shows the *whole* recording squeezed into the same
///   width — a long note condenses, exactly as asked, because the envelope is
///   bucketed down to however many bars fit rather than cropped.
/// * **While playing** the part already heard is drawn in full colour and the
///   rest is held back, which is the only progress indicator a voice note gets.
///
/// A note that arrived from the server has no envelope — nothing decodes the
/// audio to recover one — so [seed] stands in with a shape derived from the
/// file's own id. It is stable per file (the same attachment always draws the
/// same bars) and it never pretends to be silent, which a flat line would.
class VoiceWave extends StatelessWidget {
  const VoiceWave({
    super.key,
    required this.envelope,
    required this.progress,
    required this.live,
    required this.barWidth,
    required this.gap,
    this.seed,
    this.played = kVoiceWaveLive,
    this.unplayed = kVoiceWaveRest,
  });

  /// Loudness samples, 0…1, oldest first.
  final List<double> envelope;

  /// How much of the note has been played, 0…1.
  final double progress;

  /// True while the microphone is live: the newest samples are pinned to the
  /// right edge and older ones run off the left.
  final bool live;

  final double barWidth;
  final double gap;

  /// Stands in for [envelope] when there is none.
  final String? seed;

  final Color played;
  final Color unplayed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _WavePainter(
        envelope: envelope,
        progress: progress,
        live: live,
        // Captured as a plain int here on purpose: the recorder appends to the
        // same list object every frame, so comparing the lists themselves — or
        // reading their length inside the comparison — would always find them
        // equal, and the wave would never repaint while it is being drawn.
        revision: envelope.length,
        barWidth: barWidth,
        gap: gap,
        seed: seed,
        played: played,
        unplayed: unplayed,
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter({
    required this.envelope,
    required this.progress,
    required this.live,
    required this.revision,
    required this.barWidth,
    required this.gap,
    required this.seed,
    required this.played,
    required this.unplayed,
  });

  final List<double> envelope;
  final double progress;
  final bool live;

  /// [envelope]'s length at the moment this painter was built.
  final int revision;

  final double barWidth;
  final double gap;
  final String? seed;
  final Color played;
  final Color unplayed;

  @override
  void paint(Canvas canvas, Size size) {
    final double pitch = barWidth + gap;
    final int bars = ((size.width + gap) / pitch).floor();
    if (bars <= 0) return;

    final List<double> levels = _levels(bars);
    final double centre = size.height / 2;
    // A bar is never nothing: silence is a dot on the centre line, which is
    // what says "recording, and quiet" rather than "not recording".
    final double minHeight = barWidth;
    final double span = size.height - minHeight;
    final int filled = (levels.length * progress).round();

    for (int i = 0; i < levels.length; i++) {
      final double height = minHeight + span * levels[i].clamp(0.0, 1.0);
      final double x = size.width - (levels.length - i) * pitch + gap;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, centre - height / 2, barWidth, height),
          Radius.circular(barWidth / 2),
        ),
        Paint()..color = progress > 0 && i < filled ? played : unplayed,
      );
    }
  }

  /// [bars] levels to draw, however many samples there are.
  List<double> _levels(int bars) {
    if (envelope.isEmpty) return _seeded(bars);
    if (live) {
      // The tail, pinned right. A take shorter than the window keeps its own
      // length so the wave grows out of the middle rather than starting full.
      final int from = math.max(0, envelope.length - bars);
      return envelope.sublist(from);
    }
    if (envelope.length <= bars) return envelope;

    // Bucket down to the bars that fit, taking each bucket's peak: an average
    // would flatten a loud syllable into its neighbours and turn every long
    // recording into the same grey band.
    final List<double> levels = <double>[];
    final double per = envelope.length / bars;
    for (int i = 0; i < bars; i++) {
      final int start = (i * per).floor();
      final int end = math.min(envelope.length, ((i + 1) * per).ceil());
      double peak = 0;
      for (int j = start; j < end; j++) {
        if (envelope[j] > peak) peak = envelope[j];
      }
      levels.add(peak);
    }
    return levels;
  }

  /// A shape for a note whose levels are not known, derived from [seed] so it
  /// is the same every time that file is drawn.
  List<double> _seeded(int bars) {
    final String key = seed ?? '';
    if (key.isEmpty) return List<double>.filled(bars, 0.12);

    int hash = 0x811C9DC5;
    for (final int unit in key.codeUnits) {
      hash = (hash ^ unit) * 0x01000193 & 0x7FFFFFFF;
    }
    final math.Random random = math.Random(hash);
    return <double>[
      for (int i = 0; i < bars; i++)
        // Two overlaid waves plus a little noise: enough shape that it reads
        // as speech, never so tall that it claims to be louder than it was.
        (0.30 +
                0.22 * math.sin(i * 0.55 + hash % 7) +
                0.16 * math.sin(i * 0.21) +
                0.14 * random.nextDouble())
            .clamp(0.06, 0.95),
    ];
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.progress != progress ||
      old.live != live ||
      old.revision != revision ||
      old.barWidth != barWidth ||
      old.gap != gap ||
      old.seed != seed ||
      old.played != played ||
      old.unplayed != unplayed;
}

/// `0:07` — a voice note's clock.
///
/// Minutes and seconds only: a task's recording is a sentence or two, and an
/// hours field would be three characters of nothing over the bars.
String formatVoiceDuration(Duration duration) {
  final int seconds = duration.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
