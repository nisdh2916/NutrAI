import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/chat_models.dart';
import '../models/db_models.dart';

export '../models/chat_models.dart';

class ChatService {
  // 실제 배포 시 환경변수로 관리
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://100.127.151.47:8001',
  ); // 학교 서버(Tailscale IP) — nutrai-server 컨테이너 8001:8000 매핑. 로컬은 --dart-define=API_BASE_URL=http://127.0.0.1:8000

  // 타임아웃 상수 — 호출 종류별 명확화
  static const Duration _streamTimeout   = Duration(seconds: 120);
  static const Duration _chatTimeout     = Duration(seconds: 180);
  static const Duration _profileTimeout  = Duration(seconds: 60);
  static const Duration _searchTimeout   = Duration(seconds: 15);
  static const Duration _recommendTimeout = Duration(seconds: 120);
  static const Duration _detectTimeout   = Duration(seconds: 30);

  static Map<String, dynamic> _buildBody(
    String message,
    UserProfileEntity? user,
    List<String> detectedFoods, {
    List<Map<String, dynamic>>? mealHistory,
    String mode = 'chat',
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
    'mode': mode,
    if (mealHistory != null) 'meal_history': mealHistory,
  };

  static Stream<String> streamMessage({
    required String message,
    UserProfileEntity? user,
    List<String> detectedFoods = const [],
    List<Map<String, dynamic>>? mealHistory,
    String mode = 'chat',
  }) async* {
    final request = http.Request('POST', Uri.parse('$_baseUrl/chat/stream'));
    request.headers['Content-Type'] = 'application/json; charset=utf-8';
    request.body = jsonEncode(_buildBody(message, user, detectedFoods, mealHistory: mealHistory, mode: mode));

    final client = http.Client();
    String buffer = '';
    try {
      final response = await client.send(request).timeout(_streamTimeout);
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
    ).timeout(_chatTimeout);

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
    ).timeout(_profileTimeout);

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

  /// 이미지를 /detect(YOLO)에 전송 → 탐지된 음식명을 detection 컬렉션에서 영양정보로 매핑
  static Future<List<FoodNutrition>> detectFoods(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/detect'));
    request.files.add(http.MultipartFile.fromBytes(
      'image',
      bytes,
      filename: imageFile.path.split(RegExp(r'[/\\]')).last,
    ));
    try {
      final streamed = await request.send().timeout(_detectTimeout);
      if (streamed.statusCode != 200) return [];
      final body = jsonDecode(await streamed.stream.bytesToString()) as Map<String, dynamic>;
      final rawList = (body['detections'] as List?) ?? [];
      final results = <FoodNutrition>[];
      for (final d in rawList) {
        final name = (d['food_name'] as String?) ?? '';
        if (name.isEmpty) continue;
        // YOLO 클래스명은 detection 컬렉션(400개)에서 영양정보 조회
        final found = await searchFood(name, collection: 'detection');
        results.add(found.isNotEmpty ? found.first : FoodNutrition(name: name));
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// 음식 이름으로 영양정보 검색
  /// collection: 'nutrition'(검색/추천 기본) | 'detection'(YOLO 탐지 매핑)
  static Future<List<FoodNutrition>> searchFood(String query, {String collection = 'nutrition'}) async {
    final res = await http.get(
      Uri.parse('$_baseUrl/food/search?q=${Uri.encodeComponent(query)}&k=1&collection=$collection'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
    ).timeout(_searchTimeout);

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
    ).timeout(_recommendTimeout);

    if (res.statusCode == 200) {
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      return RecommendResult.fromJson(json);
    }
    throw Exception('추천 서버 오류: ${res.statusCode}');
  }
}
