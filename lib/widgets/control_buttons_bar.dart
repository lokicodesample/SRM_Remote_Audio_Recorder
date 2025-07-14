import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:srm_remote_audio_app/state/recorder_state.dart';

class ControlButtonsBar extends StatelessWidget {
  const ControlButtonsBar({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RecorderState>();
    final isRecording = state.status['is_recording'] ?? false;
    final isPaused = state.status['is_paused'] ?? false;

    return Animate(
      effects: [FadeEffect(delay: 200.ms, duration: 400.ms), const SlideEffect(begin: Offset(0, 0.5))],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Stop Button
          _buildControlButton(
            context,
            icon: Icons.stop_rounded,
            label: 'Stop',
            onPressed: !isRecording ? null : state.stop,
            color: Colors.grey.shade700,
          ),
          const SizedBox(width: 20),
          // Start/Pause/Resume Button
          _buildPrimaryControlButton(
            context,
            icon: isRecording ? (isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded) : Icons.mic_rounded,
            label: isRecording ? (isPaused ? 'Resume' : 'Pause') : 'Start',
            onPressed: () {
              FocusScope.of(context).unfocus(); // Dismiss keyboard
              if (isRecording) {
                isPaused ? state.resume() : state.pause();
              } else {
                state.start(context);
              }
            },
            isRecording: isRecording,
            isPaused: isPaused,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(BuildContext context,
      {required IconData icon, required String label, VoidCallback? onPressed, Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(20),
            backgroundColor: Colors.white,
            foregroundColor: color ?? Colors.grey.shade800,
            side: BorderSide(color: Colors.grey.shade300),
            elevation: 2,
          ),
          child: Icon(icon, size: 30),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  Widget _buildPrimaryControlButton(BuildContext context,
      {required IconData icon, required String label, VoidCallback? onPressed, required bool isRecording, required bool isPaused}) {
    
    Color buttonColor = isRecording ? (isPaused ? Colors.orange.shade700 : Theme.of(context).colorScheme.secondary) : Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(24),
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
              elevation: 4,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: Icon(icon, key: ValueKey<IconData>(icon), size: 36),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
