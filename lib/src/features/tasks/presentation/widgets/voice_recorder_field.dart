import 'package:flutter/material.dart';

import '../../application/voice_note_recorder.dart';
import 'new_task_box.dart';
import 'task_glass.dart';
import 'voice_wave.dart';

/// `Səs qeydi` — the microphone, the wave it draws, and the four controls
/// around them.
///
/// The chain is the one a chat app uses, and the user asked for exactly that:
///
/// * empty — a microphone, and nothing else;
/// * recording — the wave moving with the voice, and `sil` / `dayan` / `göndər`;
/// * held — a play button appears on the left so the take can be heard before
///   it is added, and `dayan` becomes the microphone again so it can be carried
///   on with;
/// * added — the take drops to its own row below, the field goes back to being
///   an empty microphone, and the row keeps `oxut` / `sil` / `mikrofon`.
///
/// The microphone on an added row *continues* that recording rather than
/// starting another. That is why [VoiceNoteRecorder] keeps its session open
/// instead of finalising on `göndər`: AAC frames cannot be spliced together on
/// the phone, so carrying on has to mean never having stopped.
class VoiceRecorderField extends StatelessWidget {
  const VoiceRecorderField({
    super.key,
    required this.recorder,
    required this.scale,
  });

  final VoiceNoteRecorder recorder;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final List<VoiceNote> notes = recorder.notes;
    final String? failure = recorder.failure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _Pill(recorder: recorder, scale: scale),
        if (failure != null) ...<Widget>[
          SizedBox(height: 6 * scale),
          Text(
            failure,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5 * scale,
              height: 1.3,
              color: const Color(0xFFC2410C),
            ),
          ),
        ],
        for (final VoiceNote note in notes) ...<Widget>[
          SizedBox(height: 8 * scale),
          _NoteRow(recorder: recorder, note: note, scale: scale),
        ],
      ],
    );
  }
}

/// The recorder itself.
class _Pill extends StatelessWidget {
  const _Pill({required this.recorder, required this.scale});

  final VoiceNoteRecorder recorder;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final double height = 58 * scale;
    final VoiceStage stage = recorder.stage;
    final bool empty = stage == VoiceStage.idle;

    return NewTaskBox(
      radius: height / 2,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: 10 * scale),
        child: empty
            ? _MicButton(
                size: height,
                onTap: recorder.start,
                semanticLabel: 'Səs yaz',
              )
            : _Controls(recorder: recorder, scale: scale),
      ),
    );
  }
}

/// The wide microphone the empty field is.
class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.size,
    required this.onTap,
    required this.semanticLabel,
  });

  final double size;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Icon(
            Icons.mic_rounded,
            size: size * 0.46,
            color: kVoiceControlInk,
          ),
        ),
      ),
    );
  }
}

/// What sits in the pill once there is a take in it.
class _Controls extends StatelessWidget {
  const _Controls({required this.recorder, required this.scale});

  final VoiceNoteRecorder recorder;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final VoiceStage stage = recorder.stage;
    final VoiceNote? draft = recorder.draft;
    final bool recording = stage == VoiceStage.recording;
    final bool playing = recorder.isPlaying(null);

    return Row(
      children: <Widget>[
        // Only once the microphone is held: there is nothing to listen back to
        // while it is still running.
        if (!recording)
          _RoundButton(
            icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            colour: kVoiceControlInk,
            scale: scale,
            semanticLabel: playing ? 'Dayandır' : 'Dinlə',
            onTap: recorder.togglePlayback,
          ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6 * scale),
            child: VoiceWave(
              envelope: draft?.envelope ?? const <double>[],
              progress: recorder.progressOf(null),
              live: recording,
              barWidth: 3 * scale,
              gap: 2 * scale,
            ),
          ),
        ),
        _Clock(text: formatVoiceDuration(recorder.elapsed), scale: scale),
        _RoundButton(
          icon: Icons.delete_outline_rounded,
          colour: kVoiceDeleteInk,
          scale: scale,
          semanticLabel: 'Səsi sil',
          onTap: recorder.discard,
        ),
        // While it runs, this holds it. Once held, it starts it again — the
        // same button, because it is the same idea: keep going or stop going.
        _RoundButton(
          icon: recording ? Icons.pause_rounded : Icons.mic_rounded,
          colour: kVoiceControlInk,
          scale: scale,
          semanticLabel: recording ? 'Dayandır' : 'Davam et',
          onTap: recording ? recorder.pause : () => recorder.resume(),
        ),
        _RoundButton(
          icon: Icons.send_rounded,
          colour: kVoiceControlInk,
          scale: scale,
          semanticLabel: 'Səsi əlavə et',
          onTap: recorder.commit,
        ),
      ],
    );
  }
}

/// One recording that has been added to the task.
class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.recorder,
    required this.note,
    required this.scale,
  });

  final VoiceNoteRecorder recorder;
  final VoiceNote note;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final double height = 44 * scale;
    final bool playing = recorder.isPlaying(note);
    final double progress = recorder.progressOf(note);

    return NewTaskBox(
      radius: height / 2,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: 8 * scale),
        child: Row(
          children: <Widget>[
            _RoundButton(
              icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              colour: kVoiceControlInk,
              scale: scale,
              semanticLabel: playing ? 'Dayandır' : 'Dinlə',
              onTap: () => recorder.togglePlayback(note),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6 * scale),
                child: VoiceWave(
                  envelope: note.envelope,
                  progress: progress,
                  live: false,
                  barWidth: 2.6 * scale,
                  gap: 2 * scale,
                ),
              ),
            ),
            _Clock(
              text: formatVoiceDuration(
                progress > 0 ? recorder.elapsed : note.duration,
              ),
              scale: scale,
            ),
            _RoundButton(
              icon: Icons.delete_outline_rounded,
              colour: kVoiceDeleteInk,
              scale: scale,
              semanticLabel: 'Səsi sil',
              onTap: () => recorder.discard(note),
            ),
            // Only while this recording's session is still open. Once another
            // take has been started its file is closed, and nothing on the phone
            // can add to a finished AAC stream.
            if (note.open)
              _RoundButton(
                icon: Icons.mic_rounded,
                colour: kVoiceControlInk,
                scale: scale,
                semanticLabel: 'Davamına səs əlavə et',
                onTap: () => recorder.resume(note),
              ),
          ],
        ),
      ),
    );
  }
}

/// The elapsed time, beside the wave rather than over it.
///
/// The design leaves the clock's home open. It sits here because the bars
/// carry no gap of their own to hide type in: printed over them it would be
/// unreadable at exactly the moment it matters — a loud passage — and the one
/// place with room is the space the controls already reserve.
class _Clock extends StatelessWidget {
  const _Clock({required this.text, required this.scale});

  final String text;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5 * scale),
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w500,
          fontSize: 11.5 * scale,
          height: 1,
          color: kNewTaskHintInk,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.colour,
    required this.scale,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final Color colour;
  final double scale;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double box = 34 * scale;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: box,
          child: Icon(icon, size: box * 0.62, color: colour),
        ),
      ),
    );
  }
}
