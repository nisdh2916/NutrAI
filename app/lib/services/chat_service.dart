import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/db_models.dart';

class ChatService {
  // 실제 배포 시 환경변수로 관리
  static const String _baseUrl = 'http://127.0.0.1:8000'; // adb reverse 터널링

  static Map<String, dynamic> _buildBody(
    String message,
    UserProfileEntity? user,
    List<String> detectedFoods, {
    List<Map<String, dynamic>>? mealHistory,
  }) => {
    'message': message,
    'user_profile': {
      'age': user?.age,
      'height': user?.heightCm,
      'weight': user?.weightKg,
      'gender': user?.gender,
      'goal': _mapGoal(user),
      'condition': user?.condition,
      'allergy': user?.allergy,
      'activity_level': user?.activityLevel,
      'target_kcal': user?.targetKcal,
    },
    'detected_foods': detectedFoods,
    if (mealHistory != null) 'meal_history': mealHistory,
  };

  static Stream<String> streamMessage({
    required String message,
    UserProfileEntity? user,
    List<String> detectedFoods = const [],
    List<Map<String, dynamic>>? mealHistory,
  }) async* {
    final request = http.Request('POST', Uri.parse('$_baseUrl/chat/stream'));
    request.headers['Content-Type'] = 'application/json; charset=utf-8';
    request.body = jsonEncode(_buildBody(message, user, detectedFoods, mealHistory: mealHistory));

    final client = http.Client();
    String buffer = '';
    try {
      final response = await client.send(request).timeout(const Duration(seconds: 120));
      if (response.statusCode != 200) {
        throw Exception('서버 오류: ${response.statusCode}');
      }
      await for (final bytes in response.stream) {
        buffer += utf8.decode(bytes);
        final lines = buffer.split('\n');
        // 마지막 줄은 불완전할 수 있으므로 버퍼에 보관
        buffer = lines.removeLast();
        for (final line in lines) {
          if (!line.startsWith('data: ')) continue;
          final data = line.substring(6).trim();
          if (data.isEmpty) continue;
          if (data == '[DONE]') return;
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            if (json.containsKey('error')) {
              yield '\n\n⚠️ ${json['error']}';
              return;
            }
            if (json.containsKey('chunk')) yield json['chunk'] as String;
          } catch (_) {
            // JSON 파싱 실패 시 무시하고 계속 진행
          }
        }
      }
    } finally {
      client.close();
    }
  }

  static Future<ChatResponse> sendMessage({
    required String message,
    UserProfileEntity? user,
    List<String> detectedFoods = const [],
    List<Map<String, dynamic>>? mealHistory,
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/chat'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(_buildBody(message, user, detectedFoods, mealHistory: mealHistory)),
    ).timeout(const Duration(seconds: 180));

    if (res.statusCode == 200) {
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      return ChatResponse.fromJson(json);
    }
    throw Exception('서버 오류: ${res.statusCode}');
  }

  static String _mapGoal(UserProfileEntity? user) {
    if (user == null) return '일반 건강 관리';
    if (user.goal != null && user.goal!.isNotEmpty) return user.goal!;
    return '일반 건강 관리';
  }

  /// 온보딩 대화에서 사용자 프로필 추출 (LLM 기반 NLP)
  static Future<ExtractedProfile> extractProfile(List<Map<String, String>> messages) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/profile/extract'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({'messages': messages}),
    ).timeout(const Duration(seconds: 60));

    if (res.statusCode == 200) {
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      return ExtractedProfile.fromJson(json);
    }
    throw Exception('프로필 추출 서버 오류: ${res.statusCode}');
  }

  /// MealWithFoods 리스트를 서버 전송용 JSON으로 변환
  static List<Map<String, dynamic>> mealsToHistory(List<MealWithFoods> meals) {
    return meals.map((m) => {
      'meal_type': m.meal.label,
      'foods': m.foods.map((f) => {
        'name': f.food.foodName,
        'kcal': f.totalKcal,
        'carb_g': f.totalCarbG,
        'protein_g': f.totalProteinG,
        'fat_g': f.totalFatG,
      }).toList(),
      'total_kcal': m.totalKcal,
    }).toList();
  }

  /// 음식 이름으로 영양정보 검색
  static Future<List<FoodNutrition>> searchFood(String query) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/food/search?q=${Uri.encodeComponent(query)}&k=1'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      final list = json['results'] as List;
      return list.map((e) => FoodNutrition.fromJson(e)).toList();
    }
    return [];
  }

  /// RAG 기반 맞춤 메뉴 추천
  static Future<RecommendResult> getRecommendations({
    UserProfileEntity? user,
    List<Map<String, dynamic>>? mealHistory,
    int count = 5,
    String category = '전체',
  }) async {
    final body = <String, dynamic>{
      'user_profile': {
        'age': user?.age,
        'height': user?.heightCm,
        'weight': user?.weightKg,
        'gender': user?.gender,
        'goal': _mapGoal(user),
        'condition': user?.condition,
        'allergy': user?.allergy,
        'activity_level': user?.activityLevel,
        'target_kcal': user?.targetKcal,
      },
      'count': count,
      'category': category,
      if (mealHistory != null) 'meal_history': mealHistory,
    };

    final res = await http.post(
      Uri.parse('$_baseUrl/recommend'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 120));

    if (res.statusCode == 200) {
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      return RecommendResult.fromJson(json);
    }
    throw Exception('추천 서버 오류: ${res.statusCode}');
  }
}

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

  /// 필수 정보(name, gender, age, height, weight, goal)가 모두 있는지
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
