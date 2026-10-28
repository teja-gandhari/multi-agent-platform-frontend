import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/sign_in_screen.dart';

class NexusAiApp extends StatelessWidget {
  const NexusAiApp({super.key, this.skipInitialCheck = false});
  final bool skipInitialCheck;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NexusAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: SignInScreen(skipInitialCheck: skipInitialCheck),
    );
  }
}
