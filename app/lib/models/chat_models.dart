class RecommendMenuItem {
  final String name;
  final double kcal;
  final double carb;
  final double protein;
  final double fat;
  final String reason;
  final List<String> tags;
  final bool allergenWarning;
  final List<String> allergenNames;

  const RecommendMenuItem({
    required this.name,
    this.kcal = 0,
    this.carb = 0,
    this.protein = 0,
    this.fat = 0,
    this.reason = '',
    this.tags = const [],
    this.allergenWarning = false,
    this.allergenNames = const [],
  });

  factory RecommendMenuItem.fromJson(Map<String, dynamic> json) => RecommendMenuItem(
    name: json['name'] ?? '',
    kcal: (json['kcal'] ?? 0).toDouble(),
    carb: (json['carb'] ?? 0).toDouble(),
    protein: (json['protein'] ?? 0).toDouble(),
    fat: (json['fat'] ?? 0).toDouble(),
    reason: json['reason'] ?? '',
    tags: List<String>.from(json['tags'] ?? []),
    allergenWarning: json['allergen_warning'] ?? false,
    allergenNames: List<String>.from(json['allergen_names'] ?? []),
  );
}

class RecommendResult {
  final List<RecommendMenuItem> items;
  final String coaching;

  const RecommendResult({required this.items, this.coaching = ''});

  factory RecommendResult.fromJson(Map<String, dynamic> json) => RecommendResult(
    items: (json['items'] as List).map((e) => RecommendMenuItem.fromJson(e)).toList(),
    coaching: json['coaching'] ?? '',
  );
}

class ExtractedProfile {
  final String? name;
  final String? gender;
  final int? age;
  final double? height;
  final double? weight;
  final String? goal;
  final String? activityLevel;
  final String? allergy;
  final String? condition;
  final String reply;

  const ExtractedProfile({
    this.name,
    this.gender,
    this.age,
    this.height,
    this.weight,
    this.goal,
    this.activityLevel,
    this.allergy,
    this.condition,
    this.reply = '',
  });

  bool get isComplete =>
      name != null && gender != null && age != null &&
      height != null && weight != null && goal != null;

  factory ExtractedProfile.fromJson(Map<String, dynamic> json) => ExtractedProfile(
    name: json['name'] as String?,
    gender: json['gender'] as String?,
    age: json['age'] != null ? (json['age'] as num).toInt() : null,
    height: json['height'] != null ? (json['height'] as num).toDouble() : null,
    weight: json['weight'] != null ? (json['weight'] as num).toDouble() : null,
    goal: json['goal'] as String?,
    activityLevel: json['activity_level'] as String?,
    allergy: json['allergy'] as String?,
    condition: json['condition'] as String?,
    reply: json['reply'] as String? ?? '',
  );
}

class FoodNutrition {
  final String name;
  final String category;
  final double kcal;
  final double carbG;
  final double proteinG;
  final double fatG;
  final double sodiumMg;
  final double sugarG;
  final double satFatG;
  final double cholesterolMg;
  final String serving;

  const FoodNutrition({
    required this.name,
    this.category = '',
    this.kcal = 0,
    this.carbG = 0,
    this.proteinG = 0,
    this.fatG = 0,
    this.sodiumMg = 0,
    this.sugarG = 0,
    this.satFatG = 0,
    this.cholesterolMg = 0,
    this.serving = '',
  });

  factory FoodNutrition.fromJson(Map<String, dynamic> json) => FoodNutrition(
    name: json['name'] ?? '',
    category: json['category'] ?? '',
    kcal: (json['kcal'] ?? 0).toDouble(),
    carbG: (json['carb_g'] ?? 0).toDouble(),
    proteinG: (json['protein_g'] ?? 0).toDouble(),
    fatG: (json['fat_g'] ?? 0).toDouble(),
    sodiumMg: (json['sodium_mg'] ?? 0).toDouble(),
    sugarG: (json['sugar_g'] ?? 0).toDouble(),
    satFatG: (json['sat_fat_g'] ?? 0).toDouble(),
    cholesterolMg: (json['cholesterol_mg'] ?? 0).toDouble(),
    serving: json['serving'] ?? '',
  );
}

class ChatResponse {
  final String answer;
  final List<String> sources;
  final List<String> detectedFoods;

  const ChatResponse({
    required this.answer,
    required this.sources,
    required this.detectedFoods,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) => ChatResponse(
    answer: json['answer'] as String,
    sources: List<String>.from(json['sources'] ?? []),
    detectedFoods: List<String>.from(json['detected_foods'] ?? []),
  );
}
