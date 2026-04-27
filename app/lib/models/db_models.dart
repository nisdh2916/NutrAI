// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// user_profile 테이블
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class UserProfileEntity {
  final int? id;
  final String? memberNo;
  final String nickname;
  final String? gender;
  final int? age;
  final double? heightCm;
  final double? weightKg;
  final String? activityLevel; // '낮음' | '보통' | '높음'
  final double? targetKcal;
  final String? goal;          // '다이어트' | '근육 증가' | '체중 유지' | '건강 관리'
  final String? allergy;       // 쉼표 구분: '유제품,견과류'
  final String? condition;     // 쉼표 구분: '당뇨,고혈압'
  final String createdAt;
  final String updatedAt;

  const UserProfileEntity({
    this.id,
    this.memberNo,
    required this.nickname,
    this.gender,
    this.age,
    this.heightCm,
    this.weightKg,
    this.activityLevel,
    this.targetKcal,
    this.goal,
    this.allergy,
    this.condition,
    required this.createdAt,
    required this.updatedAt,
  });

  // BMI 계산
  double? get bmi {
    if (heightCm == null || weightKg == null || heightCm! <= 0) return null;
    final h = heightCm! / 100;
    return weightKg! / (h * h);
  }

  // 기초대사량 (Mifflin-St Jeor)
  double? get bmr {
    if (heightCm == null || weightKg == null || age == null) return null;
    return gender == '남'
        ? 88.362 + (13.397 * weightKg!) + (4.799 * heightCm!) - (5.677 * age!)
        : 447.593 + (9.247 * weightKg!) + (3.098 * heightCm!) - (4.330 * age!);
  }

  String get bmiCategory {
    final b = bmi;
    if (b == null) return '';
    if (b < 18.5) return '저체중';
    if (b < 23.0) return '정상';
    if (b < 25.0) return '과체중';
    return '비만';
  }

  factory UserProfileEntity.fromMap(Map<String, dynamic> m) => UserProfileEntity(
    id:            m['id'] as int?,
    memberNo:      m['member_no'] as String?,
    nickname:      m['nickname'] as String,
    gender:        m['gender'] as String?,
    age:           m['age'] as int?,
    heightCm:      m['height_cm'] as double?,
    weightKg:      m['weight_kg'] as double?,
    activityLevel: m['activity_level'] as String?,
    targetKcal:    m['target_kcal'] as double?,
    goal:          m['goal'] as String?,
    allergy:       m['allergy'] as String?,
    condition:     m['condition'] as String?,
    createdAt:     m['created_at'] as String,
    updatedAt:     m['updated_at'] as String,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'member_no':       memberNo,
    'nickname':        nickname,
    'gender':          gender,
    'age':             age,
    'height_cm':       heightCm,
    'weight_kg':       weightKg,
    'activity_level':  activityLevel,
    'target_kcal':     targetKcal,
    'goal':            goal,
    'allergy':         allergy,
    'condition':       condition,
    'created_at':      createdAt,
    'updated_at':      updatedAt,
  };

  UserProfileEntity copyWith({
    String? nickname, String? gender, int? age,
    double? heightCm, double? weightKg,
    String? activityLevel, double? targetKcal,
    String? goal, String? allergy, String? condition,
    String? updatedAt,
  }) => UserProfileEntity(
    id: id, memberNo: memberNo,
    nickname:      nickname      ?? this.nickname,
    gender:        gender        ?? this.gender,
    age:           age           ?? this.age,
    heightCm:      heightCm      ?? this.heightCm,
    weightKg:      weightKg      ?? this.weightKg,
    activityLevel: activityLevel ?? this.activityLevel,
    targetKcal:    targetKcal    ?? this.targetKcal,
    goal:          goal          ?? this.goal,
    allergy:       allergy       ?? this.allergy,
    condition:     condition     ?? this.condition,
    createdAt:     createdAt,
    updatedAt:     updatedAt     ?? this.updatedAt,
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// food 테이블
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class FoodEntity {
  final int? id;
  final String? foodNo;
  final String foodName;
  final double kcal;
  final double carbG;
  final double proteinG;
  final double fatG;
  final String createdAt;
  final String updatedAt;

  const FoodEntity({
    this.id,
    this.foodNo,
    required this.foodName,
    required this.kcal,
    required this.carbG,
    required this.proteinG,
    required this.fatG,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FoodEntity.fromMap(Map<String, dynamic> m) => FoodEntity(
    id:        m['id'] as int?,
    foodNo:    m['food_no'] as String?,
    foodName:  m['food_name'] as String,
    kcal:      (m['kcal'] as num).toDouble(),
    carbG:     (m['carb_g'] as num).toDouble(),
    proteinG:  (m['protein_g'] as num).toDouble(),
    fatG:      (m['fat_g'] as num).toDouble(),
    createdAt: m['created_at'] as String,
    updatedAt: m['updated_at'] as String,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'food_no':   foodNo,
    'food_name': foodName,
    'kcal':      kcal,
    'carb_g':    carbG,
    'protein_g': proteinG,
    'fat_g':     fatG,
    'created_at':createdAt,
    'updated_at':updatedAt,
  };
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// meal 테이블
// meal_type: 'breakfast' | 'lunch' | 'dinner' | 'snack'
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class MealEntity {
  final int? id;
  final String? mealNo;
  final int userId;
  final String mealType;  // 'breakfast' | 'lunch' | 'dinner' | 'snack'
  final String eatenAt;   // ISO8601 문자열
  final String? memo;
  final String? photoPath;
  final String createdAt;
  final String updatedAt;

  const MealEntity({
    this.id,
    this.mealNo,
    required this.userId,
    required this.mealType,
    required this.eatenAt,
    this.memo,
    this.photoPath,
    required this.createdAt,
    required this.updatedAt,
  });

  // meal_type → 한국어 라벨
  String get label {
    const m = {'breakfast': '아침', 'lunch': '점심', 'dinner': '저녁', 'snack': '간식'};
    return m[mealType] ?? mealType;
  }

  // 한국어 라벨 → meal_type
  static String typeFromLabel(String label) {
    const m = {'아침': 'breakfast', '점심': 'lunch', '저녁': 'dinner', '간식': 'snack'};
    return m[label] ?? 'breakfast';
  }

  // eatenAt 시간 표시 (HH:MM AM/PM)
  String get timeDisplay {
    try {
      final dt = DateTime.parse(eatenAt);
      final h  = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m  = dt.minute.toString().padLeft(2, '0');
      final ap = dt.hour < 12 ? 'AM' : 'PM';
      return '$h:$m $ap';
    } catch (_) {
      return eatenAt;
    }
  }

  factory MealEntity.fromMap(Map<String, dynamic> m) => MealEntity(
    id:        m['id'] as int?,
    mealNo:    m['meal_no'] as String?,
    userId:    m['user_id'] as int,
    mealType:  m['meal_type'] as String,
    eatenAt:   m['eaten_at'] as String,
    memo:      m['memo'] as String?,
    photoPath: m['photo_path'] as String?,
    createdAt: m['created_at'] as String,
    updatedAt: m['updated_at'] as String,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'meal_no':    mealNo,
    'user_id':    userId,
    'meal_type':  mealType,
    'eaten_at':   eatenAt,
    'memo':       memo,
    'photo_path': photoPath,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// meal_food 테이블
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class MealFoodEntity {
  final int? id;
  final int mealId;
  final int foodId;
  final double? amountG;
  final double servingCount;
  final String createdAt;
  final String updatedAt;

  const MealFoodEntity({
    this.id,
    required this.mealId,
    required this.foodId,
    this.amountG,
    this.servingCount = 1.0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MealFoodEntity.fromMap(Map<String, dynamic> m) => MealFoodEntity(
    id:           m['id'] as int?,
    mealId:       m['meal_id'] as int,
    foodId:       m['food_id'] as int,
    amountG:      m['amount_g'] != null ? (m['amount_g'] as num).toDouble() : null,
    servingCount: (m['serving_count'] as num? ?? 1).toDouble(),
    createdAt:    m['created_at'] as String,
    updatedAt:    m['updated_at'] as String,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'meal_id':      mealId,
    'food_id':      foodId,
    'amount_g':     amountG,
    'serving_count':servingCount,
    'created_at':   createdAt,
    'updated_at':   updatedAt,
  };
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 조인 결과 모델 (meal + meal_food + food 합산)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class MealWithFoods {
  final MealEntity meal;
  final List<MealFoodJoin> foods;

  const MealWithFoods({required this.meal, required this.foods});

  double get totalKcal    => foods.fold(0.0, (s, f) => s + f.totalKcal);
  double get totalCarbG   => foods.fold(0.0, (s, f) => s + f.totalCarbG);
  double get totalProteinG=> foods.fold(0.0, (s, f) => s + f.totalProteinG);
  double get totalFatG    => foods.fold(0.0, (s, f) => s + f.totalFatG);

  String get summary {
    if (foods.isEmpty) return '—';
    if (foods.length == 1) return foods.first.food.foodName;
    return '${foods.first.food.foodName} 외 ${foods.length - 1}개';
  }
}

// meal_food + food 조인 한 행
class MealFoodJoin {
  final MealFoodEntity mealFood;
  final FoodEntity food;

  const MealFoodJoin({required this.mealFood, required this.food});

  double get totalKcal     => food.kcal     * mealFood.servingCount;
  double get totalCarbG    => food.carbG    * mealFood.servingCount;
  double get totalProteinG => food.proteinG * mealFood.servingCount;
  double get totalFatG     => food.fatG     * mealFood.servingCount;
}
