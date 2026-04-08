import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/db_models.dart';

class ChatService {
  // 실제 배포 시 환경변수로 관리
  static const String _baseUrl = 'http://10.0.2.2:8000'; // Android 에뮬레이터
  // 실기기 or 웹 테스트 시: 'http://127.0.0.1:8000'

  static Map<String, dynamic> _buildBody(String message, UserProfileEntity? user, List<String> detectedFoods) => {
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
  };

  static Stream<String> streamMessage({
    required String message,
    UserProfileEntity? user,
    List<String> detectedFoods = const [],
  }) async* {
    final request = http.Request('POST', Uri.parse('$_baseUrl/chat/stream'));
    request.headers['Content-Type'] = 'application/json; charset=utf-8';
    request.body = jsonEncode(_buildBody(message, user, detectedFoods));

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
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/chat'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(_buildBody(message, user, detectedFoods)),
    ).timeout(const Duration(seconds: 180));

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
