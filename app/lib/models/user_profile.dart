class UserProfile {
  String name;
  String gender; // '남' or '여'
  int? age;
  double? height; // cm
  double? weight; // kg
  String goal;           // '다이어트', '체중 유지', '근육 증진', '건강 관리'
  String activityLevel;  // '낮음', '보통', '높음'
  String allergy;        // 쉼표 구분: '유제품, 견과류'
  String condition;      // 쉼표 구분: '당뇨, 고혈압'

  UserProfile({
    this.name = '',
    this.gender = '남',
    this.age,
    this.height,
    this.weight,
    this.goal = '다이어트',
    this.activityLevel = '보통',
    this.allergy = '',
    this.condition = '',
  });

  double? get bmi {
    if (height == null || weight == null || height! <= 0) return null;
    final h = height! / 100;
    return weight! / (h * h);
  }

  double? get bmr {
    if (height == null || weight == null || age == null) return null;
    // Mifflin-St Jeor Equation
    if (gender == '남') {
      return 88.362 + (13.397 * weight!) + (4.799 * height!) - (5.677 * age!);
    } else {
      return 447.593 + (9.247 * weight!) + (3.098 * height!) - (4.330 * age!);
    }
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
