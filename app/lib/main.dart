import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'database/database_helper.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_chat_screen.dart';
import 'screens/main_tab_screen.dart';
import 'models/user_profile.dart';

// ── 개발 중 DB 리셋 플래그 ──────────────────────────
// true  → 앱 실행할 때마다 DB를 초기화해서 온보딩부터 시작
// false → 기존 유저 데이터 유지 (배포 전 반드시 false로)
const bool kResetDbOnStart = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 개발용 DB 리셋
  if (kResetDbOnStart) {
    await DatabaseHelper.instance.deleteDatabase();
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: const NutrAIApp(),
    ),
  );
}

class NutrAIApp extends StatelessWidget {
  const NutrAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutrAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const _RootRouter(),
    );
  }
}

// ── 라우터: DB에 사용자 있으면 홈, 없으면 온보딩 ──────
class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.green400),
        ),
      );
    }

    // DB에 사용자 있음 → 홈으로
    if (state.user != null) {
      final u = state.user!;
      return MainTabScreen(
        profile: UserProfile(
          name: u.nickname,
          gender: u.gender ?? '남',
          age: u.age,
          height: u.heightCm,
          weight: u.weightKg,
          goal: '다이어트',
        ),
      );
    }

    // 사용자 없음 → 온보딩
    return const OnboardingChatScreen();
  }
}
