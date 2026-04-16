import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';

// ──────────────────────────────────────────────
// AI 코치 채팅 화면 (RAG 연동)
// ──────────────────────────────────────────────
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final List<_Message> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _isLoading = false;

  // 빠른 질문 추천
  static const _quickQuestions = [
    '오늘 점심 뭐 먹을까요?',
    '다이어트 중인데 추천해줘요',
    '당뇨에 좋은 식단은?',
    '운동 후 먹을 음식 추천',
  ];

  @override
  void initState() {
    super.initState();
    _addBotMessage('안녕하세요! 저는 NutrAI 영양 코치예요 🌿\n식단 추천, 영양 정보, 건강 고민 — 뭐든 편하게 물어보세요! 😊');
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _addBotMessage(String text, {bool animated = true}) {
    setState(() => _messages.add(_Message(text: text, isBot: true, animated: animated)));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;
    _inputCtrl.clear();

    setState(() {
      _messages.add(_Message(text: text, isBot: false, animated: true));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final appState = context.read<AppState>();
      final user = appState.user;
      final todayMeals = appState.todayMeals;
      final mealHistory = todayMeals.isNotEmpty
          ? ChatService.mealsToHistory(todayMeals)
          : null;
      final response = await ChatService.sendMessage(
        message: text,
        user: user,
        mealHistory: mealHistory,
      );
      setState(() {
        _messages.add(_Message(text: response.answer, isBot: true));
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(_Message(
          text: '서버 연결 오류: $e',
          isBot: true,
        ));
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          if (_messages.length == 1) _buildQuickQuestions(),
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, size: 18, color: AppColors.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.green400,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.green400.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.smart_toy_rounded, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('NutrAI 코치', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text('RAG 기반 맞춤 식단 추천', style: TextStyle(fontSize: 11, color: AppColors.green400)),
            ],
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Divider(height: 0.5, color: AppColors.border),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (_, i) {
        if (_isLoading && i == _messages.length) return _TypingIndicator();
        return _MessageBubble(message: _messages[i]);
      },
    );
  }

  Widget _buildQuickQuestions() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('빠른 질문', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _quickQuestions.map((q) => GestureDetector(
              onTap: () => _sendMessage(q),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.green50,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(q, style: const TextStyle(fontSize: 13, color: AppColors.green600, fontWeight: FontWeight.w600)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: AppColors.white,
      padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              onSubmitted: _sendMessage,
              enabled: !_isLoading,
              maxLines: null,
              style: const TextStyle(fontSize: 13.5),
              decoration: InputDecoration(
                hintText: '식단에 대해 물어보세요...',
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.green400, width: 1.5)),
                filled: true,
                fillColor: AppColors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isLoading ? null : () => _sendMessage(_inputCtrl.text),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _isLoading ? AppColors.gray100 : AppColors.green400,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isLoading ? Icons.hourglass_empty_rounded : Icons.send_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// 메시지 모델
// ──────────────────────────────────────────────
class _Message {
  final String text;
  final bool isBot;
  bool animated; // 등장 애니메이션 완료 여부
  _Message({required this.text, required this.isBot, this.animated = false});
}

// ──────────────────────────────────────────────
// 말풍선 위젯 (봇 메시지: 등장 애니메이션)
// ──────────────────────────────────────────────
class _MessageBubble extends StatefulWidget {
  final _Message message;
  const _MessageBubble({required this.message});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    final needsAnim = widget.message.isBot && !widget.message.animated;
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: needsAnim ? 0.0 : 1.0,
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    if (needsAnim) {
      _animCtrl.forward();
      widget.message.animated = true;
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBot = widget.message.isBot;
    Widget bubble = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isBot) ...[
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: AppColors.green400,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.green400.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(Icons.smart_toy_rounded, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isBot ? AppColors.botBubble : AppColors.green400,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isBot ? 4 : 18),
                  bottomRight: Radius.circular(isBot ? 18 : 4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: isBot
                  ? _RichBotText(text: widget.message.text)
                  : Text(
                      widget.message.text,
                      style: const TextStyle(fontSize: 13.5, height: 1.55, color: Colors.white),
                    ),
            ),
          ),
          if (!isBot) ...[
            const SizedBox(width: 8),
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: AppColors.green50, shape: BoxShape.circle, border: Border.all(color: AppColors.green100)),
              child: const Center(child: Text('나', style: TextStyle(fontSize: 10, color: AppColors.green800, fontWeight: FontWeight.w500))),
            ),
          ],
        ],
      ),
    );

    if (isBot) {
      return FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(position: _slideAnim, child: bubble),
      );
    }
    return bubble;
  }
}

// ──────────────────────────────────────────────
// 봇 메시지 리치 텍스트 (마크다운 파싱 + 음식명 탭)
// ──────────────────────────────────────────────
class _RichBotText extends StatelessWidget {
  final String text;
  const _RichBotText({required this.text});

  static const _baseStyle = TextStyle(fontSize: 13.5, height: 1.55, color: AppColors.textPrimary);
  static const _boldStyle = TextStyle(fontSize: 13.5, height: 1.55, color: AppColors.textPrimary, fontWeight: FontWeight.w700);
  static const _foodStyle = TextStyle(
    fontSize: 13.5, height: 1.55,
    color: AppColors.green600, fontWeight: FontWeight.w700,
    decoration: TextDecoration.underline, decorationColor: AppColors.green100,
  );

  // 음식명 패턴 (숫자. **이름** 형태)
  static final _foodBoldPattern = RegExp(r'\*\*(.+?)\*\*');
  // 섹션 번호 패턴 (1. 2. 3.)
  static final _listNumPattern = RegExp(r'^(\d+)\.\s');
  // 대시 리스트 패턴
  static final _dashPattern = RegExp(r'^[-•]\s');

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final children = <Widget>[];

    for (final line in lines) {
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 6));
        continue;
      }

      final trimmed = line.trim();

      // 번호 목록 (1. **메뉴** ...)
      final numMatch = _listNumPattern.firstMatch(trimmed);
      if (numMatch != null) {
        final rest = trimmed.substring(numMatch.end);
        children.add(Padding(
          padding: const EdgeInsets.only(left: 4, top: 3, bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20, height: 20,
                margin: const EdgeInsets.only(top: 2, right: 8),
                decoration: BoxDecoration(
                  color: AppColors.green50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(numMatch.group(1)!,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green600)),
                ),
              ),
              Expanded(child: _buildRichLine(context, rest)),
            ],
          ),
        ));
        continue;
      }

      // 대시 리스트 (- 항목)
      if (_dashPattern.hasMatch(trimmed)) {
        final rest = trimmed.replaceFirst(_dashPattern, '');
        children.add(Padding(
          padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 7, right: 8),
                child: CircleAvatar(radius: 2.5, backgroundColor: AppColors.green400),
              ),
              Expanded(child: _buildRichLine(context, rest)),
            ],
          ),
        ));
        continue;
      }

      // 일반 텍스트
      children.add(_buildRichLine(context, trimmed));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  /// 한 줄 내에서 **bold** 파싱
  Widget _buildRichLine(BuildContext context, String line) {
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in _foodBoldPattern.allMatches(line)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: line.substring(lastEnd, match.start), style: _baseStyle));
      }
      final boldText = match.group(1)!;
      // 음식명 판별: 한글 2자 이상이면 탭 가능 음식명으로 처리
      final isFood = RegExp(r'[가-힣]{2,}').hasMatch(boldText) && boldText.length <= 20;
      if (isFood) {
        spans.add(TextSpan(
          text: boldText,
          style: _foodStyle,
          recognizer: TapGestureRecognizer()..onTap = () => _showFoodPopup(context, boldText),
        ));
      } else {
        spans.add(TextSpan(text: boldText, style: _boldStyle));
      }
      lastEnd = match.end;
    }

    if (lastEnd < line.length) {
      spans.add(TextSpan(text: line.substring(lastEnd), style: _baseStyle));
    }

    if (spans.isEmpty) {
      return Text(line, style: _baseStyle);
    }
    return RichText(text: TextSpan(children: spans));
  }

  static void _showFoodPopup(BuildContext context, String foodName) async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.green400)),
    );

    try {
      final results = await ChatService.searchFood(foodName);
      if (!context.mounted) return;
      Navigator.pop(context);

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$foodName" 영양정보를 찾을 수 없습니다.')),
        );
        return;
      }

      final food = results.first;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _FoodDetailSheet(food: food),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('영양정보 조회에 실패했습니다.')),
        );
      }
    }
  }
}

// ──────────────────────────────────────────────
// 영양정보 바텀시트 팝업
// ──────────────────────────────────────────────
class _FoodDetailSheet extends StatelessWidget {
  final FoodNutrition food;
  const _FoodDetailSheet({required this.food});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 드래그 핸들
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.gray200, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          // 음식 이름 & 카테고리
          Text(food.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          if (food.category.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(food.category, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
          if (food.serving.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('기준: ${food.serving}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 16),
          // 칼로리 강조
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.green50,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                const Text('🔥 칼로리', style: TextStyle(fontSize: 13, color: AppColors.green600, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  '${food.kcal.toStringAsFixed(0)} kcal',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.green600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 주요 영양소 그리드
          Row(
            children: [
              _NutrientTile(label: '탄수화물', value: '${food.carbG.toStringAsFixed(1)}g', color: const Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              _NutrientTile(label: '단백질', value: '${food.proteinG.toStringAsFixed(1)}g', color: const Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              _NutrientTile(label: '지방', value: '${food.fatG.toStringAsFixed(1)}g', color: const Color(0xFFEF4444)),
            ],
          ),
          const SizedBox(height: 12),
          // 세부 영양소
          _DetailRow(label: '나트륨', value: '${food.sodiumMg.toStringAsFixed(0)}mg'),
          _DetailRow(label: '당류', value: '${food.sugarG.toStringAsFixed(1)}g'),
          if (food.satFatG > 0) _DetailRow(label: '포화지방산', value: '${food.satFatG.toStringAsFixed(1)}g'),
          if (food.cholesterolMg > 0) _DetailRow(label: '콜레스테롤', value: '${food.cholesterolMg.toStringAsFixed(0)}mg'),
        ],
      ),
    );
  }
}

class _NutrientTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _NutrientTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// 타이핑 인디케이터 (상태 텍스트 포함)
// ──────────────────────────────────────────────
class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _anims;

  // 상태 메시지 순환
  static const _statusMessages = [
    '영양 데이터 검색 중',
    'AI가 답변 작성 중',
    '맞춤 분석 중',
  ];
  int _statusIndex = 0;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true, period: Duration(milliseconds: 600 + i * 150)));
    _anims = _controllers.map((c) => Tween<double>(begin: 0.3, end: 1.0).animate(c)).toList();

    // 3초마다 상태 메시지 변경
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return false;
      setState(() => _statusIndex = (_statusIndex + 1) % _statusMessages.length);
      return true;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: AppColors.green400,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.green400.withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 1))],
            ),
            child: const Icon(Icons.smart_toy_rounded, size: 15, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16), bottomLeft: Radius.circular(4)),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...List.generate(3, (i) => AnimatedBuilder(
                  animation: _anims[i],
                  builder: (_, __) => Padding(
                    padding: EdgeInsets.only(right: i < 2 ? 4.0 : 0),
                    child: Opacity(
                      opacity: _anims[i].value,
                      child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.green400, shape: BoxShape.circle)),
                    ),
                  ),
                )),
                const SizedBox(width: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _statusMessages[_statusIndex],
                    key: ValueKey(_statusIndex),
                    style: const TextStyle(fontSize: 11, color: AppColors.gray400),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
