import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/db_models.dart';

class ChatService {
  // 실제 배포 시 환경변수로 관리
  static const String _baseUrl = 'http://10.0.2.2:8000'; // Android 에뮬레이터
  // 실기기 or 웹 테스트 시: 'http://127.0.0.1:8000'

  static Future<ChatResponse> sendMessage({
    required String message,
    UserProfileEntity? user,
    List<String> detectedFoods = const [],
  }) async {
    final body = jsonEncode({
      'message': message,
      'user_profile': {
        'age': user?.age,
        'height': user?.heightCm,
        'weight': user?.weightKg,
        'goal': _mapGoal(user),
        'condition': null,
        'allergy': null,
      },
      'detected_foods': detectedFoods,
    });

    final res = await http.post(
      Uri.parse('$_baseUrl/chat'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: body,
    ).timeout(const Duration(seconds: 60));

    if (res.statusCode == 200) {
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      return ChatResponse.fromJson(json);
    }
    throw Exception('서버 오류: ${res.statusCode}');
  }

  static String _mapGoal(UserProfileEntity? user) {
    if (user == null) return '일반 건강 관리';
    // activityLevel 또는 별도 goal 필드가 생기면 여기서 매핑
    return '일반 건강 관리';
  }
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
