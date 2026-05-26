/// 봇 메시지 텍스트 파싱 유틸리티.
/// UI 의존성 없는 순수 함수들만 포함.
class ChatMessageParser {
  ChatMessageParser._();

  static final foodBoldPattern = RegExp(r'\*\*(.+?)\*\*');
  static final listNumPattern  = RegExp(r'^(\d+)\.\s');
  static final dashPattern     = RegExp(r'^[-•]\s');

  static const nonFoodLabels = <String>{
    '음식명', '메뉴명', '칼로리', '추천 이유', '추천이유', '코칭 메시지', '코칭메시지',
    '추천', '성분', '영양', '식단', '이유', '메뉴', '기준', '재료', '효능',
  };

  /// 볼드 텍스트가 음식 이름인지 판별합니다.
  static bool isFoodName(String text) =>
      RegExp(r'[가-힣]{2,}').hasMatch(text) &&
      text.length <= 20 &&
      !nonFoodLabels.contains(text);

  /// 메시지에서 특정 음식의 칼로리·추천 이유를 추출합니다.
  static Map<String, String> parseFoodInfo(String message, String foodName) {
    final lines = message.split('\n');
    String kcal = '';
    String reason = '';
    for (int i = 0; i < lines.length; i++) {
      if (!lines[i].contains(foodName)) continue;
      for (int j = i; j < lines.length && j < i + 5; j++) {
        if (kcal.isEmpty) {
          final m = RegExp(r'칼로리[:\s]*(\d+)\s*kcal').firstMatch(lines[j])
              ?? RegExp(r'[(\s](\d+)\s*kcal').firstMatch(lines[j]);
          if (m != null) kcal = m.group(1)!;
        }
        if (reason.isEmpty && (lines[j].contains('추천 이유') || lines[j].contains('이유:'))) {
          reason = lines[j]
              .replaceAll(RegExp(r'\*\*.*?\*\*:?\s*'), '')
              .replaceAll(RegExp(r'추천\s*이유:?\s*'), '')
              .trim();
        }
      }
      break;
    }
    return {'kcal': kcal, 'reason': reason};
  }
}
