import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:srm_remote_audio_app/state/recorder_state.dart';

class TimerCard extends StatelessWidget {
  const TimerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RecorderState>();
    final status = state.status;
    final isRecording = status['is_recording'] ?? false;
    final isPaused = status['is_paused'] ?? false;
    final elapsed = (status['elapsed_time'] ?? 0).toInt();
    final timerText =
        '${(elapsed ~/ 3600).toString().padLeft(2, '0')}:${((elapsed % 3600) ~/ 60).toString().padLeft(2, '0')}:${(elapsed % 60).toString().padLeft(2, '0')}';

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (isRecording) {
      if (isPaused) {
        statusText = 'Paused';
        statusColor = Colors.orange.shade700;
        statusIcon = Icons.pause_circle_filled_rounded;
      } else {
        statusText = 'Recording';
        statusColor = Colors.redAccent;
        statusIcon = Icons.mic_rounded;
      }
    } else {
      statusText = 'Ready to Record';
      statusColor = Theme.of(context).colorScheme.secondary;
      statusIcon = Icons.check_circle_rounded;
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isRecording && !isPaused)
                  const Icon(Icons.circle, color: Colors.redAccent, size: 16)
                      .animate(onPlay: (c) => c.repeat())
                      .fade(duration: 700.ms, curve: Curves.easeInOut)
                else
                  Icon(statusIcon, color: statusColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: statusColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Text(
                timerText,
                key: ValueKey(timerText),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fade(duration: 300.ms).slideY(begin: 0.2, curve: Curves.easeOutCubic);
  }
}
