import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:srm_remote_audio_app/theme.dart';
import 'package:collection/collection.dart';

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

// --- Scanner Screen ---
class ScannerScreen extends StatelessWidget {
  const ScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: MobileScanner(
        onDetect: (capture) {
          final String? code = capture.barcodes.first.rawValue;
          if (code != null && Navigator.canPop(context)) {
            Navigator.pop(context, code);
          }
        },
      ),
    );
  }
}

// --- Connect Screen ---
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _urlController = TextEditingController();
  bool _isLoading = false;

  void _connect() async {
    if (_urlController.text.isEmpty) return;
    setState(() => _isLoading = true);

    final success = await context.read<RecorderState>().connect(_urlController.text.trim());

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to connect. Check the URL and server.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _scanQrCode() async {
    final scannedUrl = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );

    if (scannedUrl != null && scannedUrl.isNotEmpty) {
      _urlController.text = scannedUrl;
      _connect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Color.lerp(Theme.of(context).colorScheme.surface, Colors.white, 0.5)!,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset('assets/images/srm_logo.png', height: 150)
                    .animate()
                    .fade(duration: 500.ms)
                    .slideY(begin: -0.5, curve: Curves.easeOutCubic),
                const SizedBox(height: 32),
                Text(
                  "SRM Remote Recorder",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w600),
                ).animate().fade(delay: 200.ms, duration: 500.ms),
                const SizedBox(height: 12),
                Text(
                  "Connect to your Raspberry Pi server",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                ).animate().fade(delay: 300.ms, duration: 500.ms),
                const SizedBox(height: 48),
                _buildConnectForm(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: 'Pi IP or ngrok URL',
            prefixIcon: Icon(Icons.link_rounded),
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: const Text('Scan QR Code'),
          onPressed: _scanQrCode,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _isLoading ? null : _connect,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                )
              : const Text('Connect Manually'),
        ),
      ],
    ).animate().fade(delay: 400.ms, duration: 500.ms).slideY(begin: 0.2, curve: Curves.easeOutCubic);
  }
}

// --- Recorder Screen ---
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


// --- State Management ---
class RecorderState extends ChangeNotifier {
  String? _baseUrl;
  Timer? _timer;
  http.Client? _client;

  final meetingIdController = TextEditingController();
  final meetingTopicController = TextEditingController();

  Map<String, dynamic> _status = {
    'is_recording': false,
    'is_paused': false,
    'elapsed_time': 0.0,
    'meeting_id': '',
    'meeting_topic': '',
  };
  String _message = 'Disconnected';

  bool get isConnected => _baseUrl != null;
  Map<String, dynamic> get status => _status;
  String get message => _message;

  @override
  void dispose() {
    meetingIdController.dispose();
    meetingTopicController.dispose();
    _timer?.cancel();
    _client?.close();
    super.dispose();
  }

  Uri _buildUri(String path) {
    // Basic validation to prepend http if missing
    var url = _baseUrl!;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    // Append port if not present and not an ngrok url
    if (!url.contains(':') && !url.contains('ngrok')) {
       url = '$url:5000';
    }
    return Uri.parse('$url/$path');
  }

  Future<bool> connect(String url) async {
    _baseUrl = url;
    _client = http.Client();
    try {
      final response = await _client!.get(_buildUri('status')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        _status = json.decode(response.body);
        meetingIdController.text = _status['meeting_id'] ?? '';
        meetingTopicController.text = _status['meeting_topic'] ?? '';
        _startPolling();
        _message = 'Connected. Ready to record.';
        notifyListeners();
        return true;
      }
    } catch (e) {
      disconnect(notify: false); // disconnect without notifying to prevent flicker
    }
    return false;
  }

  void disconnect({bool notify = true}) {
    _baseUrl = null;
    _timer?.cancel();
    _client?.close();
    _client = null;
    _status = {'is_recording': false, 'is_paused': false, 'elapsed_time': 0.0};
    _message = 'Disconnected';
    if (notify) {
      notifyListeners();
    }
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_baseUrl == null) {
        _timer?.cancel();
        return;
      }
      try {
        final response = await _client!.get(_buildUri('status')).timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final newStatus = json.decode(response.body);
          // Basic check to see if status actually changed before notifying
          if (!const DeepCollectionEquality().equals(newStatus, _status)) {
            _status = newStatus;
            notifyListeners();
          }
        } else {
           _message = 'Connection lost.';
           disconnect();
        }
      } catch (e) {
        _message = 'Connection lost.';
        disconnect();
      }
    });
  }

  Future<void> _sendCommand(String command, {Map<String, String>? body}) async {
    if (_baseUrl == null) return;
    try {
      await _client!.post(
        _buildUri(command),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body ?? {}),
      ).timeout(const Duration(seconds: 5));
      // Don't wait for polling, update status immediately for responsiveness
      await _updateStatus();
    } catch (e) {
       _message = 'Failed to send command.';
       disconnect();
    }
  }
  
  Future<void> _updateStatus() async {
     if (_baseUrl == null) return;
      try {
        final response = await _client!.get(_buildUri('status')).timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          _status = json.decode(response.body);
          notifyListeners();
        }
      } catch (e) {
        // Ignore update error, polling will catch it
      }
  }

  void start(BuildContext context) {
    final meetingId = meetingIdController.text;
    final topic = meetingTopicController.text;
    if (meetingId.isEmpty) {
      // Show a snackbar to inform the user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a Meeting ID before starting.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }
    _sendCommand('start', body: {'meeting_id': meetingId, 'topic': topic});
  }
  void stop() => _sendCommand('stop');
  void pause() => _sendCommand('pause');
  void resume() => _sendCommand('resume');
}