// ── 음식 단위 ──────────────────────────────────────
class MealFood {
  final String name;
  final double carb;    // g
  final double protein; // g
  final double fat;     // g
  final double kcal;

  const MealFood({
    required this.name,
    required this.carb,
    required this.protein,
    required this.fat,
    required this.kcal,
  });
}

// ── 끼니 기록 ──────────────────────────────────────
class MealRecord {
  final String label; // 아침 / 점심 / 저녁
  final String time;  // "10:00 AM"
  final List<MealFood> foods;

  const MealRecord({
    required this.label,
    required this.time,
    required this.foods,
  });

  double get totalKcal    => foods.fold(0.0, (s, f) => s + f.kcal);
  double get totalCarb    => foods.fold(0.0, (s, f) => s + f.carb);
  double get totalProtein => foods.fold(0.0, (s, f) => s + f.protein);
  double get totalFat     => foods.fold(0.0, (s, f) => s + f.fat);

  /// 첫 번째 음식명 + "외 N개" 요약 텍스트
  String get summary {
    if (foods.isEmpty) return '—';
    if (foods.length == 1) return foods.first.name;
    return '${foods.first.name} 외 ${foods.length - 1}개';
  }
}

// ── 날짜별 식단 묶음 ────────────────────────────────
class DayMealData {
  final DateTime date;
  final List<MealRecord> meals;

  const DayMealData({required this.date, required this.meals});

  double get totalKcal => meals.fold(0.0, (s, m) => s + m.totalKcal);
  bool get isEmpty => meals.isEmpty;
}

// ── 샘플 데이터 생성 헬퍼 ───────────────────────────
class MealSampleData {
  static List<MealRecord> forDate(DateTime date) {
    // 짝수 날은 데이터 있음, 홀수 날 일부는 비움 (데모용)
    if (date.day % 7 == 0) return [];

    return [
      MealRecord(
        label: '아침', time: '08:30 AM',
        foods: [
          const MealFood(name: '비빔밥',    carb: 65, protein: 18, fat: 8,  kcal: 410),
          const MealFood(name: '된장찌개',  carb: 12, protein: 8,  fat: 4,  kcal: 115),
          const MealFood(name: '제육볶음',  carb: 20, protein: 25, fat: 14, kcal: 310),
        ],
      ),
      MealRecord(
        label: '점심', time: '12:30 PM',
        foods: [
          const MealFood(name: '삼겹살',    carb: 5,  protein: 28, fat: 32, kcal: 430),
          const MealFood(name: '부대찌개',  carb: 30, protein: 18, fat: 12, kcal: 300),
          const MealFood(name: '공기밥',    carb: 70, protein: 5,  fat: 1,  kcal: 310),
        ],
      ),
      if (date.day % 2 == 0)
        MealRecord(
          label: '저녁', time: '07:00 PM',
          foods: [
            const MealFood(name: '한정식',  carb: 80, protein: 30, fat: 15, kcal: 560),
            const MealFood(name: '미역국',  carb: 8,  protein: 5,  fat: 2,  kcal: 70),
          ],
        ),
    ];
  }
}
