import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrai/main.dart';
import 'package:nutrai/models/db_models.dart';
import 'package:nutrai/providers/app_state.dart';
import 'package:provider/provider.dart';

class _ReadyAppState extends AppState {
  @override
  bool get loading => false;

  @override
  UserProfileEntity? get user => const UserProfileEntity(
        nickname: '테스트',
        gender: '남',
        age: 28,
        heightCm: 170,
        weightKg: 65,
        createdAt: '2026-05-04T00:00:00',
        updatedAt: '2026-05-04T00:00:00',
      );
}

void main() {
  testWidgets('앱 기본 렌더링 테스트', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>(
        create: (_) => _ReadyAppState(),
        child: const NutrAIApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
