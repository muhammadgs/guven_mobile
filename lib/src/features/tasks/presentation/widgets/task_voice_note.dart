import 'package:flutter/material.dart';

import '../../application/task_voice_player.dart';
import '../../domain/task_attachment.dart';
import 'task_glass.dart';
import 'voice_wave.dart';

/// One voice note on an open card.
///
/// The same row a chat app shows: play, a wave that fills as it plays, how far
/// in it is, and a way to keep the file. It is not a file chip — the design
/// gives recordings a section of their own, `Səs qeydləri`, and a chip reading
/// `Səs qeydi` with no way to hear it would be the one attachment on this
/// screen you cannot actually open.
///
/// The wave is drawn from the file's id rather than from the audio: nothing on
/// the phone decodes a downloaded recording to recover its levels, and the
/// envelope the recorder measured never leaves the device it was recorded on.
/// It is stable per file and it never claims to be silent — see [VoiceWave].
class TaskVoiceNote extends StatelessWidget {
  const TaskVoiceNote({
    super.key,
    required this.file,
    required this.player,
    required this.scale,
    required this.saving,
    required this.onSave,
  });

  final TaskAttachment file;
  final TaskVoicePlayer player;
  final double scale;

  /// True while this file is being downloaded for the phone to open.
  final bool saving;

  /// Hands the file to whatever the phone keeps audio in.
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final double height = 44 * scale;
    final bool playing = player.isPlaying(file.id);
    final bool loading = player.isLoading(file.id);
    final String? failure = player.failureFor(file.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: 8 * scale),
          decoration: ShapeDecoration(
            color: const Color(0xB8FFFFFF),
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
          child: Row(
            children: <Widget>[
              _Button(
                scale: scale,
                semanticLabel: playing ? 'Dayandır' : 'Dinlə',
                onTap: loading ? null : () => player.toggle(file),
                child: loading
                    ? Padding(
                        padding: EdgeInsets.all(6 * scale),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kVoiceControlInk,
                        ),
                      )
                    : Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 22 * scale,
                        color: kVoiceControlInk,
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6 * scale),
                  child: VoiceWave(
                    envelope: const <double>[],
                    seed: file.id,
                    progress: player.progressOf(file.id),
                    live: false,
                    barWidth: 2.6 * scale,
                    gap: 2 * scale,
                  ),
                ),
              ),
              if (player.hasClock(file.id))
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5 * scale),
                  child: Text(
                    formatVoiceDuration(player.clockFor(file.id)),
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      fontSize: 11.5 * scale,
                      height: 1,
                      color: kGlassInkMuted,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ),
              _Button(
                scale: scale,
                semanticLabel: 'Səs qeydini saxla',
                onTap: saving ? null : onSave,
                child: saving
                    ? Padding(
                        padding: EdgeInsets.all(6 * scale),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kVoiceDeleteInk,
                        ),
                      )
                    : Icon(
                        Icons.save_alt_rounded,
                        size: 19 * scale,
                        color: kVoiceDeleteInk,
                      ),
              ),
            ],
          ),
        ),
        if (failure != null)
          Padding(
            padding: EdgeInsets.only(top: 4 * scale, left: 12 * scale),
            child: Text(
              failure,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5 * scale,
                height: 1.25,
                color: const Color(0xFFC2410C),
              ),
            ),
          ),
      ],
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.scale,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
  });

  final double scale;
  final String semanticLabel;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double box = 32 * scale;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: box,
          child: Center(child: child),
        ),
      ),
    );
  }
}
