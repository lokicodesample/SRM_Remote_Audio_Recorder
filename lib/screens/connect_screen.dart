import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:srm_remote_audio_app/state/recorder_state.dart';
import 'package:srm_remote_audio_app/screens/scanner_screen.dart';

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
