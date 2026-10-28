import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexusai_frontend/app.dart';

void main() {
  testWidgets('renders NexusAI sign-in screen on desktop viewport', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const NexusAiApp(skipInitialCheck: true));
    await tester.pump();

    expect(find.text('NexusAI'), findsWidgets);
    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('renders NexusAI loading state', (tester) async {
    await tester.pumpWidget(const NexusAiApp(skipInitialCheck: false));
    expect(find.text('Connecting to NexusAI...'), findsOneWidget);
  });
}
