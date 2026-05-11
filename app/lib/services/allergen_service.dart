import 'dart:convert';
import 'package:http/http.dart' as http;

/// 알레르겐 카테고리 → 키워드 매핑의 단일 소스.
///
/// 앱 시작 시 서버 GET /allergens 로 최신 목록을 받아 메모리에 캐시한다.
/// 서버 미응답(오프라인 등) 시 하드코딩된 fallback을 사용한다.
class AllergenService {
  AllergenService._();
  static final instance = AllergenService._();

  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  // 알레르겐 카테고리 → 매칭 키워드
  Map<String, List<String>> _keywords = _fallbackKeywords;

  // 설정 화면에서 사용자에게 보여줄 카테고리 순서
  List<String> _categories = List.unmodifiable(_fallbackKeywords.keys.toList());

  Map<String, List<String>> get keywords => _keywords;
  List<String> get categories => _categories;

  /// 앱 시작 시 한 번 호출. 실패해도 fallback으로 동작한다.
  Future<void> init() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/allergens'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final raw = body['keywords'] as Map<String, dynamic>;
        _keywords = raw.map(
          (k, v) => MapEntry(k, List<String>.from(v as List)),
        );
        _categories = List.unmodifiable(
          (body['categories'] as List).cast<String>(),
        );
      }
    } catch (_) {
      // 오프라인 또는 서버 미응답 — fallback 유지
    }
  }

  /// 음식명에서 사용자 알레르기 카테고리에 해당하는 항목 반환.
  List<String> detect(String foodName, String? userAllergy) {
    if (userAllergy == null || userAllergy.isEmpty) return [];
    final userCategories = userAllergy.split(',').map((e) => e.trim());
    final found = <String>[];
    for (final category in userCategories) {
      final kws = _keywords[category];
      if (kws == null) continue;
      if (kws.any(foodName.contains)) found.add(category);
    }
    return found;
  }
}

// 서버 응답 전 또는 오프라인 시 사용하는 fallback.
// ai/allergens.py 의 ALLERGEN_KEYWORDS 와 동일하게 유지해야 한다.
const _fallbackKeywords = <String, List<String>>{
  '유제품':  ['우유', '치즈', '버터', '요거트', '크림', '유청', '밀크', '라떼', '카푸치노', '아이스크림'],
  '견과류':  ['아몬드', '호두', '캐슈', '땅콩', '잣', '피스타치오', '마카다미아', '헤이즐넛', '피넛', '견과'],
  '갑각류':  ['새우', '게', '랍스터', '크랩', '대게'],
  '밀':     ['빵', '파스타', '면', '국수', '라면', '우동', '스파게티', '밀가루', '만두', '냉면', '소면', '떡볶이'],
  '글루텐':  ['빵', '파스타', '면', '국수', '라면', '우동', '밀가루'],
  '계란':    ['계란', '달걀', '에그', '오믈렛', '마요네즈', '스크램블'],
  '대두':    ['두부', '된장', '간장', '두유', '콩국수', '낫토', '청국장', '순두부', '콩'],
  '복숭아':  ['복숭아', '피치'],
  '토마토':  ['토마토', '케첩'],
  '고등어':  ['고등어'],
  '조개류':  ['조개', '홍합', '굴', '전복', '바지락', '오징어', '낙지', '문어'],
};
