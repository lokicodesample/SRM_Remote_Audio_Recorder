import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:srm_remote_audio_app/state/recorder_state.dart';
import 'package:srm_remote_audio_app/widgets/timer_card.dart';
import 'package:srm_remote_audio_app/widgets/meeting_details_card.dart';
import 'package:srm_remote_audio_app/widgets/control_buttons_bar.dart';

class RecorderScreen extends StatelessWidget {
  const RecorderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recorder Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Disconnect',
            onPressed: () => context.read<RecorderState>().disconnect(),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard on tap
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 120), // Padding for FAB
          children: const [
            TimerCard(),
            MeetingDetailsCard(),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: const ControlButtonsBar(),
    );
  }
}
