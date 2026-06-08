import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'profile_summary_screen.dart';

class UserSetupScreen extends StatefulWidget {
  final UserProfile profile;
  const UserSetupScreen({super.key, required this.profile});

  @override
  State<UserSetupScreen> createState() => _UserSetupScreenState();
}

class _UserSetupScreenState extends State<UserSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  final TextEditingController _birthDateCtrl = TextEditingController();
  final TextEditingController _heightCtrl = TextEditingController();
  final TextEditingController _weightCtrl = TextEditingController();
  late final TextEditingController _allergyCtrl;
  late final TextEditingController _conditionCtrl;

  DateTime? _birthDate;
  String _selectedGender = '남';
  late String _selectedGoal;
  late String _selectedActivity;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile.name);
    _birthDate = widget.profile.birthDate;
    if (_birthDate != null) _birthDateCtrl.text = _formatDate(_birthDate!);
    _selectedGender = widget.profile.gender;
    _selectedGoal = widget.profile.goal;
    _selectedActivity = widget.profile.activityLevel;
    _allergyCtrl = TextEditingController(text: widget.profile.allergy);
    _conditionCtrl = TextEditingController(text: widget.profile.condition);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _birthDateCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _allergyCtrl.dispose();
    _conditionCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthDateCtrl.text = _formatDate(picked);
      });
    }
  }

  // 만나이 계산
  int? get _internationalAge {
    if (_birthDate == null) return null;
    final now = DateTime.now();
    int a = now.year - _birthDate!.year;
    if (now.month < _birthDate!.month ||
        (now.month == _birthDate!.month && now.day < _birthDate!.day)) {
      a--;
    }
    return a;
  }

  // 세는 나이 계산
  int? get _koreanAge {
    if (_birthDate == null) return null;
    return DateTime.now().year - _birthDate!.year + 1;
  }

  String get _ageDisplayText {
    final k = _koreanAge;
    final i = _internationalAge;
    if (k == null) return '';
    if (i != null && i != k) return '$k세 (만 $i세)';
    return '$k세';
  }

  // ── 실시간 계산 ──
  double? get _bmi {
    final h = double.tryParse(_heightCtrl.text);
    final w = double.tryParse(_weightCtrl.text);
    if (h == null || w == null || h <= 0) return null;
    return w / ((h / 100) * (h / 100));
  }

  double? get _bmr {
    final h = double.tryParse(_heightCtrl.text);
    final w = double.tryParse(_weightCtrl.text);
    final age = _internationalAge;
    if (h == null || w == null || age == null) return null;
    return _selectedGender == '남'
        ? 88.362 + (13.397 * w) + (4.799 * h) - (5.677 * age)
        : 447.593 + (9.247 * w) + (3.098 * h) - (4.330 * age);
  }

  String get _bmiText {
    final b = _bmi;
    if (b == null) return '';
    String cat;
    if (b < 18.5) {
      cat = '저체중';
    } else if (b < 23.0) {
      cat = '정상';
    } else if (b < 25.0) {
      cat = '과체중';
    } else {
      cat = '비만';
    }
    return '${b.toStringAsFixed(1)} ($cat)';
  }

  String get _bmrText {
    final b = _bmr;
    if (b == null) return '';
    return '약 ${b.round()}kcal';
  }

  void _onNext() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final profile = UserProfile(
      name: _nameCtrl.text.trim(),
      gender: _selectedGender,
      birthDate: _birthDate,
      height: double.tryParse(_heightCtrl.text),
      weight: double.tryParse(_weightCtrl.text),
      goal: _selectedGoal,
      activityLevel: _selectedActivity,
      allergy: _allergyCtrl.text.trim(),
      condition: _conditionCtrl.text.trim(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileSummaryScreen(profile: profile)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          '사용자 기본 설정',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
          children: [
            // ── 이름 ──
            _HorizField(
              label: '이름',
              child: _InlineInput(
                  controller: _nameCtrl,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '이름을 입력해주세요' : null),
            ),
            const SizedBox(height: 22),

            // ── 성별 ──
            _HorizField(
              label: '성별',
              child: _GenderToggle(
                selected: _selectedGender,
                onChanged: (v) => setState(() => _selectedGender = v),
              ),
            ),
            const SizedBox(height: 22),

            // ── 생년월일 ──
            _HorizField(
              label: '생년월일',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _pickBirthDate,
                    child: AbsorbPointer(
                      child: _InlineInput(
                        controller: _birthDateCtrl,
                        validator: (_) =>
                            _birthDate == null ? '생년월일을 선택해주세요' : null,
                      ),
                    ),
                  ),
                  if (_birthDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _ageDisplayText,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.green600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ── 키 ──
            _HorizField(
              label: '키',
              child: Row(children: [
                Expanded(
                  child: _InlineInput(
                    controller: _heightCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                    ],
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n < 50 || n > 250) return '올바른 키';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                const Text('cm',
                    style: TextStyle(
                        fontSize: 15, color: AppColors.textSecondary)),
              ]),
            ),
            const SizedBox(height: 22),

            // ── 몸무게 ──
            _HorizField(
              label: '몸무게',
              child: Row(children: [
                Expanded(
                  child: _InlineInput(
                    controller: _weightCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                    ],
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      if (n == null || n < 10 || n > 300) return '올바른 몸무게';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                const Text('kg',
                    style: TextStyle(
                        fontSize: 15, color: AppColors.textSecondary)),
              ]),
            ),

            const SizedBox(height: 32),

            // ── 건강 목표 ──
            _HorizField(
              label: '목표',
              child: _ChipSelector(
                options: const ['다이어트', '체중 유지', '근육 증진', '건강 관리'],
                selected: _selectedGoal,
                onChanged: (v) => setState(() => _selectedGoal = v),
              ),
            ),
            const SizedBox(height: 22),

            // ── 활동량 ──
            _HorizField(
              label: '활동량',
              child: _ChipSelector(
                options: const ['낮음', '보통', '높음'],
                selected: _selectedActivity,
                onChanged: (v) => setState(() => _selectedActivity = v),
              ),
            ),
            const SizedBox(height: 22),

            // ── 알레르기 ──
            _HorizField(
              label: '알레르기',
              child: _InlineInput(
                controller: _allergyCtrl,
                keyboardType: TextInputType.text,
              ),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.only(left: 76),
              child: Text('예: 유제품, 견과류 (없으면 비워두세요)',
                  style: TextStyle(fontSize: 11, color: AppColors.gray400)),
            ),
            const SizedBox(height: 22),

            // ── 질환 ──
            _HorizField(
              label: '질환',
              child: _InlineInput(
                controller: _conditionCtrl,
                keyboardType: TextInputType.text,
              ),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.only(left: 76),
              child: Text('예: 당뇨, 고혈압 (없으면 비워두세요)',
                  style: TextStyle(fontSize: 11, color: AppColors.gray400)),
            ),

            const SizedBox(height: 40),

            // ── BMI ──
            _AutoCalcField(label: '당신의 신체질량지수(BMI)', value: _bmiText),
            const SizedBox(height: 18),

            // ── BMR ──
            _AutoCalcField(label: '당신의 기초대사량(BMR)', value: _bmrText),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(onPressed: _onNext, label: '다음 단계로'),
    );
  }
}

// ─────────────────────────────────────────
// 서브 위젯
// ─────────────────────────────────────────

class _HorizField extends StatelessWidget {
  final String label;
  final Widget child;
  const _HorizField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 60,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary)),
        ),
        const SizedBox(width: 16),
        Expanded(child: child),
      ],
    );
  }
}

class _InlineInput extends StatelessWidget {
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  const _InlineInput({
    required this.controller,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.gray50,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: AppColors.green400, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.red)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.red, width: 1.5)),
      ),
    );
  }
}

class _GenderToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _GenderToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: ['남', '여'].map((g) {
        final isSel = selected == g;
        return Padding(
          padding: EdgeInsets.only(right: g == '남' ? 8 : 0),
          child: InkWell(
            onTap: () => onChanged(g),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 56,
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSel ? AppColors.green400 : AppColors.gray50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(g,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSel ? AppColors.white : AppColors.gray400,
                  )),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ChipSelector extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  const _ChipSelector(
      {required this.options, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSel = selected == opt;
        return InkWell(
          onTap: () => onChanged(opt),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSel ? AppColors.green400 : AppColors.gray50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isSel ? AppColors.green400 : AppColors.border,
                  width: isSel ? 1.5 : 0.5),
            ),
            child: Text(opt,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSel ? AppColors.white : AppColors.gray400,
                )),
          ),
        );
      }).toList(),
    );
  }
}

class _AutoCalcField extends StatelessWidget {
  final String label;
  final String value;
  const _AutoCalcField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Container(
          width: 180,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
              color: AppColors.gray50, borderRadius: BorderRadius.circular(8)),
          child: Text(
            value.isNotEmpty ? value : '',
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  const _BottomBar({required this.onPressed, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green400,
          foregroundColor: AppColors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(double.infinity, 52),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}
