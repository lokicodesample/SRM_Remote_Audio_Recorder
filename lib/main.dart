import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:srm_remote_audio_app/screens/connect_screen.dart';
import 'package:srm_remote_audio_app/screens/recorder_screen.dart';
import 'package:srm_remote_audio_app/state/recorder_state.dart';
import 'package:srm_remote_audio_app/theme.dart';

// Main entry point of the app
void main() {
  // Ensure widgets are initialized before setting preferred orientations
  WidgetsFlutterBinding.ensureInitialized();
  // Lock orientation to portrait mode
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ChangeNotifierProvider(
      create: (context) => RecorderState(),
      child: const SrmRemoteAudioApp(),
    ),
  );
}

// The root widget of the application
class SrmRemoteAudioApp extends StatelessWidget {
  const SrmRemoteAudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SRM Remote Recorder',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const AppBody(),
    );
  }
}

// A widget that decides which screen to show with an animated transition
class AppBody extends StatelessWidget {
  const AppBody({super.key});

  @override
  Widget build(BuildContext context) {
    final isConnected = context.watch<RecorderState>().isConnected;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: isConnected
          ? const RecorderScreen(key: ValueKey('RecorderScreen'))
          : const ConnectScreen(key: ValueKey('ConnectScreen')),
    );
  }
}
