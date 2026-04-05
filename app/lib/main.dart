import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_chat_screen.dart';

void main() {
  runApp(const NutrAIApp());
}

class NutrAIApp extends StatelessWidget {
  const NutrAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutrAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const OnboardingChatScreen(),
    );
  }
}
