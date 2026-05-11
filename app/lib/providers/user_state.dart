import '../models/db_models.dart';
import '../repositories/user_repository.dart';

/// 사용자 도메인 상태 및 비즈니스 로직.
/// AppState가 소유하며 notifyListeners 호출은 AppState에 위임.
class UserState {
  final _repo = UserRepository();

  UserProfileEntity? _user;
  UserProfileEntity? get user => _user;
  int? get userId => _user?.id;

  Future<void> load() async {
    _user = await _repo.getFirstUser();
  }

  Future<void> save({
    required String nickname,
    String? gender,
    int? age,
    double? heightCm,
    double? weightKg,
    String? activityLevel,
    double? targetKcal,
    String? goal,
    String? allergy,
    String? condition,
  }) async {
    final now = DateTime.now().toIso8601String();
    if (_user == null) {
      final newUser = UserProfileEntity(
        nickname:      nickname,
        gender:        gender,
        age:           age,
        heightCm:      heightCm,
        weightKg:      weightKg,
        activityLevel: activityLevel,
        targetKcal:    targetKcal,
        goal:          goal,
        allergy:       allergy,
        condition:     condition,
        createdAt:     now,
        updatedAt:     now,
      );
      final id = await _repo.createUser(newUser);
      _user = await _repo.getUserById(id);
    } else {
      final updated = _user!.copyWith(
        nickname:      nickname,
        gender:        gender,
        age:           age,
        heightCm:      heightCm,
        weightKg:      weightKg,
        activityLevel: activityLevel,
        targetKcal:    targetKcal,
        goal:          goal,
        allergy:       allergy,
        condition:     condition,
        updatedAt:     now,
      );
      await _repo.updateUser(updated);
      _user = updated;
    }
  }

  void clear() => _user = null;
}
