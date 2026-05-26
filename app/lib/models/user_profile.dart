class UserProfile {
  String name;
  String gender;
  int? age;           // fallback (birthDate 없을 때만 사용)
  DateTime? birthDate;
  double? height;
  double? weight;
  String goal;
  String activityLevel;
  String allergy;
  String condition;

  UserProfile({
    this.name = '',
    this.gender = '남',
    this.age,
    this.birthDate,
    this.height,
    this.weight,
    this.goal = '다이어트',
    this.activityLevel = '보통',
    this.allergy = '',
    this.condition = '',
  });

  // 만나이: 생일이 지났으면 (올해 - 출생연도), 아직이면 -1
  int? get internationalAge {
    if (birthDate != null) {
      final now = DateTime.now();
      int a = now.year - birthDate!.year;
      if (now.month < birthDate!.month ||
          (now.month == birthDate!.month && now.day < birthDate!.day)) {
        a--;
      }
      return a;
    }
    return age;
  }

  // 세는 나이: 태어난 해 기준 + 1
  int? get koreanAge {
    if (birthDate != null) return DateTime.now().year - birthDate!.year + 1;
    if (age != null) return age! + 1;
    return null;
  }

  // "XX세 (만 XX세)" — 두 값이 같으면 괄호 생략
  String get ageDisplayText {
    final k = koreanAge;
    final i = internationalAge;
    if (k == null) return '—';
    if (i != null && i != k) return '$k세 (만 $i세)';
    return '$k세';
  }

  double? get bmi {
    if (height == null || weight == null || height! <= 0) return null;
    final h = height! / 100;
    return weight! / (h * h);
  }

  double? get bmr {
    if (height == null || weight == null) return null;
    final a = internationalAge;
    if (a == null) return null;
    return gender == '남'
        ? 88.362 + (13.397 * weight!) + (4.799 * height!) - (5.677 * a)
        : 447.593 + (9.247 * weight!) + (3.098 * height!) - (4.330 * a);
  }

  String get bmiCategory {
    final b = bmi;
    if (b == null) return '';
    if (b < 18.5) return '저체중';
    if (b < 23.0) return '정상';
    if (b < 25.0) return '과체중';
    return '비만';
  }
}
