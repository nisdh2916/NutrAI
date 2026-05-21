/// 알레르기 키워드 매핑 및 탐지 유틸 (단일 출처).
///
/// 서버의 `server/common/allergens.py`와 동일한 매핑을 유지하여
/// 클라이언트·서버 알레르기 판정 결과가 어긋나지 않도록 한다.
const Map<String, List<String>> kAllergenKeywords = {
  '유제품':   ['치즈', '우유', '버터', '요거트', '크림', '아이스크림', '라떼', '카푸치노', '밀크', '유청'],
  '견과류':   ['땅콩', '호두', '아몬드', '캐슈', '피스타치오', '견과', '잣', '마카다미아', '헤이즐넛', '피넛'],
  '갑각류':   ['새우', '게', '랍스터', '크랩', '대게'],
  '계란':     ['달걀', '계란', '오믈렛', '스크램블', '에그', '마요네즈'],
  '밀/글루텐':['라면', '빵', '국수', '우동', '파스타', '쿠키', '케이크', '떡볶이', '만두', '냉면', '소면', '밀가루'],
  '대두':     ['두부', '된장', '간장', '청국장', '두유', '순두부', '콩', '낫토'],
  '생선':     ['고등어', '연어', '참치', '갈치', '조기', '멸치', '명태', '생선'],
  '돼지고기': ['삼겹살', '제육', '돈까스', '베이컨', '햄', '소시지', '족발', '보쌈'],
  '닭고기':   ['닭가슴살', '치킨', '닭갈비', '닭볶음', '통닭'],
  '쇠고기':   ['불고기', '갈비', '스테이크', '육회', '소고기', '한우'],
  '해산물':   ['조개', '홍합', '전복', '굴', '해물', '해산물', '오징어', '낙지', '문어'],
};

/// 음식 이름에 사용자 알레르기 성분이 포함되는지 검사한다.
/// 반환: 매칭된 알레르겐 카테고리 목록.
List<String> detectAllergens(String foodName, String? userAllergy) {
  if (userAllergy == null || userAllergy.isEmpty) return const [];
  final userAllergens = userAllergy
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty && e != '없음')
      .toList();
  final found = <String>[];
  for (final allergen in userAllergens) {
    final keywords = kAllergenKeywords[allergen];
    if (keywords == null) continue;
    if (keywords.any((kw) => foodName.contains(kw))) {
      found.add(allergen);
    }
  }
  return found;
}
