import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:srm_remote_audio_app/state/recorder_state.dart';

class MeetingDetailsCard extends StatelessWidget {
  const MeetingDetailsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<RecorderState>();
    final isRecording = context.watch<RecorderState>().status['is_recording'] ?? false;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Meeting Details", style: theme.textTheme.titleLarge),
            const SizedBox(height: 20),
            TextField(
              controller: state.meetingIdController,
              decoration: const InputDecoration(labelText: 'Meeting ID*'),
              enabled: !isRecording,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: state.meetingTopicController,
              decoration: const InputDecoration(labelText: 'Meeting Topic'),
              enabled: !isRecording,
            ),
          ],
        ),
      ),
    ).animate().fade(delay: 100.ms, duration: 300.ms).slideY(begin: 0.2, curve: Curves.easeOutCubic);
  }
}
