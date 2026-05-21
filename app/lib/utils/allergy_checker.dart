const allergenKeywords = <String, List<String>>{
  '유제품': ['우유', '치즈', '버터', '요거트', '크림', '유청', '밀크', '라떼', '카푸치노', '아이스크림'],
  '견과류': ['아몬드', '호두', '캐슈', '땅콩', '잣', '피스타치오', '마카다미아', '헤이즐넛', '피넛', '견과'],
  '갑각류': ['새우', '게', '랍스터', '크랩', '대게'],
  '밀':    ['빵', '파스타', '면', '국수', '라면', '우동', '스파게티', '밀가루', '만두', '냉면', '소면', '떡볶이'],
  '글루텐': ['빵', '파스타', '면', '국수', '라면', '우동', '밀가루'],
  '계란':  ['계란', '달걀', '에그', '오믈렛', '마요네즈', '스크램블'],
  '대두':  ['두부', '된장', '간장', '두유', '콩국수', '낫토', '청국장', '순두부', '콩'],
  '복숭아': ['복숭아', '피치'],
  '토마토': ['토마토', '케첩'],
  '고등어': ['고등어'],
  '조개류': ['조개', '홍합', '굴', '전복', '바지락', '오징어', '낙지', '문어'],
};

/// 음식 이름에 포함된 사용자 알레르기 카테고리 목록을 반환합니다.
///
/// [userAllergy] 쉼표 또는 공백으로 구분된 알레르기 문자열 (예: "유제품, 견과류")
List<String> detectAllergens(String foodName, String? userAllergy) {
  if (userAllergy == null || userAllergy.isEmpty) return [];
  final userAllergens = userAllergy
      .split(RegExp(r'[,\s]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty && e != '없음');
  final found = <String>[];
  for (final allergen in userAllergens) {
    final keywords = allergenKeywords[allergen] ?? [allergen];
    if (keywords.any((kw) => foodName.contains(kw))) found.add(allergen);
  }
  return found;
}
