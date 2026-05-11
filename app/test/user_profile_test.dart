import 'package:flutter_test/flutter_test.dart';
import 'package:nutrai/models/db_models.dart';

UserProfileEntity _profile({
  double? height,
  double? weight,
  int? age,
  String gender = '남',
}) =>
    UserProfileEntity(
      nickname: 'test',
      gender: gender,
      age: age,
      heightCm: height,
      weightKg: weight,
      createdAt: '2026-01-01',
      updatedAt: '2026-01-01',
    );

void main() {
  group('UserProfileEntity.bmi', () {
    test('정상 계산 — 170cm 70kg', () {
      final bmi = _profile(height: 170, weight: 70).bmi;
      expect(bmi, closeTo(24.22, 0.01));
    });

    test('키가 null이면 null 반환', () {
      expect(_profile(weight: 70).bmi, isNull);
    });

    test('몸무게가 null이면 null 반환', () {
      expect(_profile(height: 170).bmi, isNull);
    });

    test('키가 0이면 null 반환 (division guard)', () {
      expect(_profile(height: 0, weight: 70).bmi, isNull);
    });
  });

  group('UserProfileEntity.bmiCategory', () {
    test('BMI < 18.5 → 저체중', () {
      // 170cm, 50kg → BMI ≈ 17.3
      expect(_profile(height: 170, weight: 50).bmiCategory, '저체중');
    });

    test('18.5 ≤ BMI < 23 → 정상', () {
      // 170cm, 63kg → BMI ≈ 21.8
      expect(_profile(height: 170, weight: 63).bmiCategory, '정상');
    });

    test('23 ≤ BMI < 25 → 과체중', () {
      // 170cm, 68kg → BMI ≈ 23.5
      expect(_profile(height: 170, weight: 68).bmiCategory, '과체중');
    });

    test('BMI ≥ 25 → 비만', () {
      // 170cm, 80kg → BMI ≈ 27.7
      expect(_profile(height: 170, weight: 80).bmiCategory, '비만');
    });

    test('키/몸무게 없으면 빈 문자열', () {
      expect(_profile().bmiCategory, '');
    });
  });

  group('UserProfileEntity.bmr — Mifflin-St Jeor', () {
    test('남성 공식: 88.362 + 13.397W + 4.799H - 5.677A', () {
      // 170cm, 70kg, 30세 남성
      final expected = 88.362 + (13.397 * 70) + (4.799 * 170) - (5.677 * 30);
      expect(_profile(height: 170, weight: 70, age: 30, gender: '남').bmr,
          closeTo(expected, 0.001));
    });

    test('여성 공식: 447.593 + 9.247W + 3.098H - 4.330A', () {
      // 160cm, 55kg, 25세 여성
      final expected = 447.593 + (9.247 * 55) + (3.098 * 160) - (4.330 * 25);
      expect(_profile(height: 160, weight: 55, age: 25, gender: '여').bmr,
          closeTo(expected, 0.001));
    });

    test('나이 없으면 null', () {
      expect(_profile(height: 170, weight: 70).bmr, isNull);
    });

    test('키 없으면 null', () {
      expect(_profile(weight: 70, age: 30).bmr, isNull);
    });

    test('몸무게 없으면 null', () {
      expect(_profile(height: 170, age: 30).bmr, isNull);
    });
  });
}
