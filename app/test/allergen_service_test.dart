import 'package:flutter_test/flutter_test.dart';
import 'package:nutrai/services/allergen_service.dart';

void main() {
  // AllergenService.instance는 init() 없이 fallback 키워드로 동작
  final svc = AllergenService.instance;

  group('AllergenService.detect — 알레르기 없음', () {
    test('userAllergy가 null이면 빈 리스트 반환', () {
      expect(svc.detect('라면', null), isEmpty);
    });

    test('userAllergy가 빈 문자열이면 빈 리스트 반환', () {
      expect(svc.detect('라면', ''), isEmpty);
    });

    test('음식명에 해당 키워드 없으면 빈 리스트 반환', () {
      expect(svc.detect('닭가슴살', '유제품'), isEmpty);
    });
  });

  group('AllergenService.detect — 단일 알레르기 감지', () {
    test('밀 알레르기 — 라면 감지', () {
      expect(svc.detect('라면', '밀'), contains('밀'));
    });

    test('밀 알레르기 — 떡볶이 감지', () {
      // 앱 버전에만 있던 떡볶이가 통합 후 감지되는지 확인
      expect(svc.detect('떡볶이', '밀'), contains('밀'));
    });

    test('계란 알레르기 — 스크램블 감지', () {
      // 앱 버전에만 있던 스크램블이 통합 후 감지되는지 확인
      expect(svc.detect('스크램블에그', '계란'), contains('계란'));
    });

    test('대두 알레르기 — 순두부 감지', () {
      expect(svc.detect('순두부찌개', '대두'), contains('대두'));
    });

    test('갑각류 알레르기 — 새우 감지', () {
      expect(svc.detect('새우볶음밥', '갑각류'), contains('갑각류'));
    });

    test('유제품 알레르기 — 카푸치노 감지', () {
      expect(svc.detect('카푸치노', '유제품'), contains('유제품'));
    });
  });

  group('AllergenService.detect — 복합 알레르기', () {
    test('여러 알레르기 중 하나만 매칭 — 매칭된 것만 반환', () {
      final result = svc.detect('라면', '밀,갑각류');
      expect(result, contains('밀'));
      expect(result, isNot(contains('갑각류')));
    });

    test('여러 알레르기 모두 매칭', () {
      // 새우라면: 밀(라면) + 갑각류(새우) 둘 다 해당
      final result = svc.detect('새우라면', '밀,갑각류');
      expect(result, containsAll(['밀', '갑각류']));
    });

    test('쉼표+공백 구분자 처리', () {
      expect(svc.detect('두부조림', '대두, 계란'), contains('대두'));
    });
  });

  group('AllergenService.categories', () {
    test('11개 카테고리 포함', () {
      expect(svc.categories.length, 11);
    });

    test('주요 카테고리 포함 여부', () {
      expect(svc.categories, containsAll(['유제품', '견과류', '밀', '계란', '대두']));
    });
  });
}
