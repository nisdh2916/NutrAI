import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

const _kAllergens = [
  '유제품', '견과류', '갑각류', '밀', '글루텐',
  '계란', '대두', '복숭아', '토마토', '고등어', '조개류',
];

const _kConditions = [
  '당뇨', '고혈압', '고지혈증', '신장질환', '심장질환', '간질환', '통풍',
];

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('설정',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: AppColors.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── 현재 프로필 카드 ──
          if (user != null) ...[
            _SectionLabel('현재 프로필'),
            _InfoCard(items: [
              _Item('이름',     user.nickname),
              _Item('성별',     user.gender ?? '—'),
              _Item('나이',     user.age != null ? '${user.age}세' : '—'),
              _Item('키',       user.heightCm != null ? '${user.heightCm}cm' : '—'),
              _Item('몸무게',   user.weightKg != null ? '${user.weightKg}kg' : '—'),
              _Item('BMI',      user.bmi != null
                  ? '${user.bmi!.toStringAsFixed(1)} (${user.bmiCategory})' : '—'),
              _Item('기초대사량', user.bmr != null ? '약 ${user.bmr!.round()}kcal' : '—'),
            ]),
            const SizedBox(height: 16),

            // ── 건강 정보 카드 ──
            _SectionLabel('건강 정보'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    const Text('알레르기',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _formatList(user.allergy, '없음'),
                        style: const TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ]),
                ),
                Divider(height: 0.5, color: AppColors.border, indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    const Text('질환',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _formatList(user.condition, '없음'),
                        style: const TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ]),
                ),
                Divider(height: 0.5, color: AppColors.border),
                InkWell(
                  onTap: () => _editHealthInfo(context, user),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 16, color: AppColors.green400),
                      const SizedBox(width: 8),
                      const Text('알레르기·질환 편집',
                          style: TextStyle(fontSize: 14,
                              fontWeight: FontWeight.w600, color: AppColors.green400)),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.green400.withValues(alpha: 0.5)),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 24),
          ],

          // ── 프로필 재설정 ──
          _SectionLabel('계정'),
          _ActionTile(
            icon: Icons.person_outline_rounded,
            label: '프로필 재설정',
            sub: '온보딩부터 다시 시작해요',
            color: AppColors.green400,
            onTap: () => _confirmReset(context),
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.delete_outline_rounded,
            label: '모든 데이터 삭제',
            sub: '식단 기록과 프로필이 모두 삭제돼요',
            color: Colors.red,
            onTap: () => _confirmReset(context),
          ),
        ],
      ),
    );
  }

  String _formatList(String? raw, String fallback) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    final items = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    return items.isEmpty ? fallback : items.join(', ');
  }

  void _editHealthInfo(BuildContext context, dynamic user) {
    final allergies = Set<String>.from(
      ((user.allergy ?? '') as String)
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty),
    );
    final conditions = Set<String>.from(
      ((user.condition ?? '') as String)
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HealthEditSheet(
        initialAllergies: allergies,
        initialConditions: conditions,
        onSave: (newAllergies, newConditions) async {
          Navigator.pop(ctx);
          await context.read<AppState>().saveUser(
            nickname: user.nickname as String,
            allergy: newAllergies.isEmpty ? null : newAllergies.join(','),
            condition: newConditions.isEmpty ? null : newConditions.join(','),
          );
        },
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('프로필 재설정',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text(
            '모든 식단 기록과 프로필이 삭제되고\n온보딩 화면으로 이동해요.\n계속할까요?',
            style: TextStyle(fontSize: 14, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소',
                style: TextStyle(color: AppColors.gray400)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AppState>().resetUser();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green400,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 알레르기·질환 편집 바텀시트
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _HealthEditSheet extends StatefulWidget {
  final Set<String> initialAllergies;
  final Set<String> initialConditions;
  final Future<void> Function(List<String> allergies, List<String> conditions) onSave;

  const _HealthEditSheet({
    required this.initialAllergies,
    required this.initialConditions,
    required this.onSave,
  });

  @override
  State<_HealthEditSheet> createState() => _HealthEditSheetState();
}

class _HealthEditSheetState extends State<_HealthEditSheet> {
  late Set<String> _allergies;
  late Set<String> _conditions;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _allergies = Set.from(widget.initialAllergies);
    _conditions = Set.from(widget.initialConditions);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // 핸들
          const SizedBox(height: 12),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.gray200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // 타이틀
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Text('알레르기·질환 편집',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ]),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('해당 항목을 모두 선택해주세요',
                style: TextStyle(fontSize: 12, color: AppColors.gray400)),
          ),
          Divider(height: 24, color: AppColors.border),

          // 스크롤 영역
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildSection(
                  title: '알레르기',
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFE8A838),
                  items: _kAllergens,
                  selected: _allergies,
                  onToggle: (v) => setState(() {
                    if (_allergies.contains(v)) {
                      _allergies.remove(v);
                    } else {
                      _allergies.add(v);
                    }
                  }),
                ),
                const SizedBox(height: 20),
                _buildSection(
                  title: '질환',
                  icon: Icons.local_hospital_outlined,
                  color: const Color(0xFFE57373),
                  items: _kConditions,
                  selected: _conditions,
                  onToggle: (v) => setState(() {
                    if (_conditions.contains(v)) {
                      _conditions.remove(v);
                    } else {
                      _conditions.add(v);
                    }
                  }),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // 저장 버튼
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 8, 20, MediaQuery.of(context).padding.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green400,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('저장',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> items,
    required Set<String> selected,
    required ValueChanged<String> onToggle,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(title,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ]),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((item) {
          final isSelected = selected.contains(item);
          return GestureDetector(
            onTap: () => onToggle(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.12) : AppColors.gray50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? color : AppColors.border,
                  width: isSelected ? 1.5 : 0.5,
                ),
              ),
              child: Text(item,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? color : AppColors.textSecondary)),
            ),
          );
        }).toList(),
      ),
    ]);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.onSave(
      _allergies.toList(),
      _conditions.toList(),
    );
  }
}

// ─────────────────────────────────────────────────
// 서브 위젯
// ─────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: AppColors.gray400, letterSpacing: 0.5)),
  );
}

class _Item {
  final String label, value;
  const _Item(this.label, this.value);
}

class _InfoCard extends StatelessWidget {
  final List<_Item> items;
  const _InfoCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final isLast = e.key == items.length - 1;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Text(e.value.label,
                    style: const TextStyle(fontSize: 14,
                        color: AppColors.textSecondary)),
                const Spacer(),
                Text(e.value.value,
                    style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
              ]),
            ),
            if (!isLast) Divider(height: 0.5, color: AppColors.border,
                indent: 16, endIndent: 16),
          ]);
        }).toList(),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label,
      required this.sub, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 14,
                fontWeight: FontWeight.w600, color: color)),
            Text(sub, style: const TextStyle(fontSize: 12,
                color: AppColors.textSecondary)),
          ],
        )),
        Icon(Icons.chevron_right_rounded,
            size: 18, color: color.withValues(alpha: 0.5)),
      ]),
    ),
  );
}
