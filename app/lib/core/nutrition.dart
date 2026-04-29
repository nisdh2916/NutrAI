import '../models/db_models.dart';

/// 일일 영양 목표 (칼로리 + 매크로).
/// 서버의 `server/common/nutrition.py`와 동일한 산식을 사용한다.
class NutritionGoal {
  final double targetKcal;
  final double carbG;
  final double proteinG;
  final double fatG;

  const NutritionGoal({
    required this.targetKcal,
    required this.carbG,
    required this.proteinG,
    required this.fatG,
  });

  factory NutritionGoal.fromKcal(double kcal) {
    return NutritionGoal(
      targetKcal: kcal,
      // 50:25:25 비율 (탄/단/지), 1g당 4/4/9 kcal
      carbG:    kcal * 0.50 / 4.0,
      proteinG: kcal * 0.25 / 4.0,
      fatG:     kcal * 0.25 / 9.0,
    );
  }
}

const _activityFactor = <String, double>{
  '낮음': 1.375,
  '보통': 1.55,
  '높음': 1.725,
};
const _defaultTargetKcal = 2000.0;

/// Mifflin-St Jeor BMR. 입력 부족 시 null.
double? _bmr({String? gender, int? age, double? heightCm, double? weightKg}) {
  if (age == null || heightCm == null || weightKg == null || age <= 0) return null;
  final g = (gender ?? '').trim();
  if (g == '남' || g.toLowerCase() == 'm' || g.toLowerCase() == 'male') {
    return 10 * weightKg + 6.25 * heightCm - 5 * age + 5;
  }
  if (g == '여' || g.toLowerCase() == 'f' || g.toLowerCase() == 'female') {
    return 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
  }
  return 10 * weightKg + 6.25 * heightCm - 5 * age - 78;
}

/// 사용자 프로필 기반 권장 칼로리.
/// 우선순위: 명시 targetKcal → BMR×활동계수×목표보정 → 기본값
double calculateTargetKcal(UserProfileEntity? user) {
  if (user == null) return _defaultTargetKcal;
  if (user.targetKcal != null && user.targetKcal! > 0) return user.targetKcal!;

  final bmr = _bmr(
    gender: user.gender,
    age: user.age,
    heightCm: user.heightCm,
    weightKg: user.weightKg,
  );
  if (bmr == null) return _defaultTargetKcal;

  final factor = _activityFactor[user.activityLevel ?? '보통'] ?? 1.55;
  double adjustment = 1.0;
  final goal = (user.goal ?? '');
  if (goal.contains('다이어트') || goal.contains('감량')) {
    adjustment = 0.85;
  } else if (goal.contains('증량') || goal.contains('벌크')) {
    adjustment = 1.10;
  }
  return bmr * factor * adjustment;
}

NutritionGoal calculateNutritionGoal(UserProfileEntity? user) =>
    NutritionGoal.fromKcal(calculateTargetKcal(user));
