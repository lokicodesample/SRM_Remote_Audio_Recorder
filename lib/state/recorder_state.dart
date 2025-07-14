import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:collection/collection.dart';

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
    var url = _baseUrl!;
    // Check for port in the original URL before we add the "http://" prefix.
    final bool hasPort = url.contains(':');

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }

    // Append port if it wasn't in the original URL and it's not an ngrok url.
    if (!hasPort && !url.contains('ngrok')) {
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
