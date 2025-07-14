// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:srm_remote_audio_app/main.dart';

void main() {
  testWidgets('App starts with ConnectScreen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (context) => RecorderState(),
        child: const SrmRemoteAudioApp(),
      ),
    );

    // Verify that the ConnectScreen is shown.
    expect(find.byType(ConnectScreen), findsOneWidget);
    expect(find.byType(RecorderScreen), findsNothing);

    // Verify that the title of the ConnectScreen is correct.
    expect(find.text('Connect to Recorder'), findsOneWidget);

    // Verify that the input field for the IP address is present.
    expect(find.widgetWithText(TextField, 'Enter Raspberry Pi IP Address'), findsOneWidget);
  });
}
