import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../repositories/chat_repository.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../utils/allergy_checker.dart';
import '../utils/chat_message_parser.dart';

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
  final _chatRepo = ChatRepository();
  bool _isLoading = false;

  static const _quickQuestions = [
    '오늘 점심 뭐 먹을까요?',
    '다이어트 중인데 추천해줘요',
    '당뇨에 좋은 식단은?',
    '운동 후 먹을 음식 추천',
  ];

  static const _welcomeMessage =
      '안녕하세요! NutrAI 영양 코치입니다.\n무엇이 궁금하신가요? 식단 추천, 영양 정보 등 뭐든 물어보세요!';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    await _chatRepo.deleteOlderThan30Days();
    final history = await _chatRepo.getLast30Days();
    if (history.isEmpty) {
      _addBotMessage(_welcomeMessage);
      return;
    }
    setState(() {
      for (final m in history) {
        _messages.add(
            _Message(text: m.text, isBot: m.role == 'bot', animated: false));
      }
    });
    _scrollToBottom();
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('대화 초기화'),
        content: const Text('모든 대화 내용을 삭제할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _chatRepo.clearAll();
    setState(() => _messages.clear());
    _addBotMessage(_welcomeMessage);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _addBotMessage(String text, {bool animated = true}) {
    setState(() =>
        _messages.add(_Message(text: text, isBot: true, animated: animated)));
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

    final appState = context.read<AppState>();

    setState(() {
      _messages.add(_Message(text: text, isBot: false, animated: true));
      _isLoading = true;
    });
    _scrollToBottom();
    await _chatRepo.insert('user', text);

    setState(
        () => _messages.add(_Message(text: '', isBot: true, animated: false)));
    final botIndex = _messages.length - 1;
    try {
      final user = appState.user;
      final todayMeals = appState.todayMeals;
      final mealHistory =
          todayMeals.isNotEmpty ? ChatService.mealsToHistory(todayMeals) : null;

      final buffer = StringBuffer();
      await for (final chunk in ChatService.streamMessage(
        message: text,
        user: user,
        mealHistory: mealHistory,
      )) {
        buffer.write(chunk);
        if (!mounted) return;
        setState(() => _messages[botIndex] = _Message(
              text: buffer.toString(),
              isBot: true,
              animated: false,
            ));
        _scrollToBottom();
      }
      if (buffer.isNotEmpty) await _chatRepo.insert('bot', buffer.toString());
    } catch (e) {
      if (!mounted) return;
      final errText = '서버 연결 오류: $e';
      setState(
          () => _messages[botIndex] = _Message(text: errText, isBot: true));
      await _chatRepo.insert('bot', errText);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
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
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded,
            size: 18, color: AppColors.text),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: AppColors.brandSoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.smart_toy_outlined,
              size: 18, color: AppColors.brand),
        ),
        const SizedBox(width: 10),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('NutrAI 코치',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text)),
          Text('RAG 기반 맞춤 식단 추천',
              style: TextStyle(fontSize: 11, color: AppColors.brand)),
        ]),
      ]),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded,
              size: 20, color: AppColors.textMuted),
          tooltip: '대화 초기화',
          onPressed: _isLoading ? null : _clearHistory,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.line),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _MessageBubble(message: _messages[i]),
    );
  }

  Widget _buildQuickQuestions() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 0, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(right: 16, bottom: 8),
          child: Text('빠른 질문',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0)),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _quickQuestions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final q = _quickQuestions[i];
              return Semantics(
                button: true,
                label: '빠른 질문: $q',
                child: Material(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: InkWell(
                    onTap: () => _sendMessage(q),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      child: Text(q,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandText)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 2),
      ]),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.lineSoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              onSubmitted: _sendMessage,
              enabled: !_isLoading,
              textInputAction: TextInputAction.send,
              maxLines: null,
              style: const TextStyle(fontSize: 14, color: AppColors.text),
              decoration: const InputDecoration(
                hintText: '식단에 대해 물어보세요...',
                hintStyle: TextStyle(fontSize: 14, color: AppColors.textMuted),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Semantics(
              button: true,
              enabled: !_isLoading,
              label: '메시지 보내기',
              child: Material(
                color: _isLoading ? AppColors.lineStrong : AppColors.brand,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap:
                      _isLoading ? null : () => _sendMessage(_inputCtrl.text),
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      _isLoading
                          ? Icons.hourglass_empty_rounded
                          : Icons.send_rounded,
                      color: AppColors.surface,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
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
  bool animated;
  _Message({required this.text, required this.isBot, this.animated = false});
}

// ──────────────────────────────────────────────
// 말풍선 위젯
// ──────────────────────────────────────────────
class _MessageBubble extends StatefulWidget {
  final _Message message;
  const _MessageBubble({required this.message});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble>
    with SingleTickerProviderStateMixin {
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

    if (isBot && widget.message.text.isEmpty) {
      return FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(position: _slideAnim, child: _TypingIndicator()),
      );
    }

    Widget bubble = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isBot) ...[
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                  color: AppColors.brandSoft, shape: BoxShape.circle),
              child: const Icon(Icons.smart_toy_outlined,
                  size: 16, color: AppColors.brand),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isBot ? AppColors.surface : AppColors.brand,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.md),
                  topRight: const Radius.circular(AppRadius.md),
                  bottomLeft: Radius.circular(isBot ? 4 : AppRadius.md),
                  bottomRight: Radius.circular(isBot ? AppRadius.md : 4),
                ),
                boxShadow: isBot ? AppShadows.card : null,
              ),
              child: isBot
                  ? _RichBotText(text: widget.message.text)
                  : Text(widget.message.text,
                      style: const TextStyle(
                          fontSize: 14,
                          height: 1.55,
                          color: Colors.white,
                          fontWeight: FontWeight.w500)),
            ),
          ),
          if (!isBot) ...[
            const SizedBox(width: 8),
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                  color: AppColors.brandSoft, shape: BoxShape.circle),
              child: const Center(
                  child: Text('나',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.brandText,
                          fontWeight: FontWeight.w700))),
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
// 봇 메시지 리치 텍스트
// ──────────────────────────────────────────────
class _RichBotText extends StatelessWidget {
  final String text;
  const _RichBotText({required this.text});

  static const _baseStyle =
      TextStyle(fontSize: 14, height: 1.55, color: AppColors.text);
  static const _boldStyle = TextStyle(
      fontSize: 14,
      height: 1.55,
      color: AppColors.text,
      fontWeight: FontWeight.w700);
  static const _foodStyle = TextStyle(
    fontSize: 14,
    height: 1.55,
    color: AppColors.brandText,
    fontWeight: FontWeight.w700,
    decoration: TextDecoration.underline,
    decorationColor: AppColors.brandSoft,
  );

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

      final numMatch = ChatMessageParser.listNumPattern.firstMatch(trimmed);
      if (numMatch != null) {
        final rest = trimmed.substring(numMatch.end);
        children.add(Padding(
          padding: const EdgeInsets.only(left: 4, top: 3, bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(top: 2, right: 8),
                decoration: BoxDecoration(
                  color: AppColors.brandSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                    child: Text(numMatch.group(1)!,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandText))),
              ),
              Expanded(child: _buildRichLine(context, rest)),
            ],
          ),
        ));
        continue;
      }

      if (ChatMessageParser.dashPattern.hasMatch(trimmed)) {
        final rest = trimmed.replaceFirst(ChatMessageParser.dashPattern, '');
        children.add(Padding(
          padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 7, right: 8),
                child:
                    CircleAvatar(radius: 2.5, backgroundColor: AppColors.brand),
              ),
              Expanded(child: _buildRichLine(context, rest)),
            ],
          ),
        ));
        continue;
      }

      children.add(_buildRichLine(context, trimmed));
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _buildRichLine(BuildContext context, String line) {
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in ChatMessageParser.foodBoldPattern.allMatches(line)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
            text: line.substring(lastEnd, match.start), style: _baseStyle));
      }
      final boldText = match.group(1)!.trim();
      final isFood = ChatMessageParser.isFoodName(boldText);
      if (isFood) {
        spans.add(TextSpan(
          text: boldText,
          style: _foodStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () => _showFoodPopup(context, boldText, text),
        ));
      } else {
        spans.add(TextSpan(text: boldText, style: _boldStyle));
      }
      lastEnd = match.end;
    }

    if (lastEnd < line.length) {
      spans.add(TextSpan(text: line.substring(lastEnd), style: _baseStyle));
    }

    if (spans.isEmpty) return Text(line, style: _baseStyle);
    return RichText(text: TextSpan(children: spans));
  }

  static void _showFoodPopup(
      BuildContext context, String foodName, String fullMessage) {
    final info = ChatMessageParser.parseFoodInfo(fullMessage, foodName);
    final allergy =
        Provider.of<AppState>(context, listen: false).user?.allergy ?? '';
    final allergenWarning = detectAllergens(foodName, allergy);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ChatFoodSheet(
        foodName: foodName,
        kcal: info['kcal'] ?? '',
        reason: info['reason'] ?? '',
        allergenWarning: allergenWarning,
        allergy: allergy,
      ),
    );
  }
}

// ──────────────────────────────────────────────
// 채팅 음식 팝업
// ──────────────────────────────────────────────
class _ChatFoodSheet extends StatelessWidget {
  final String foodName;
  final String kcal;
  final String reason;
  final List<String> allergenWarning;
  final String allergy;
  const _ChatFoodSheet({
    required this.foodName,
    required this.kcal,
    required this.reason,
    this.allergenWarning = const [],
    this.allergy = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.lineStrong,
                borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 16),
          Text(foodName,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  letterSpacing: 0)),
          const SizedBox(height: 12),
          if (kcal.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(children: [
                const Text('칼로리',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSub)),
                const SizedBox(height: 4),
                Text('$kcal kcal',
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandDark,
                        letterSpacing: 0)),
              ]),
            ),
          if (allergenWarning.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.redSoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(children: [
                const Icon(Icons.warning_rounded,
                    size: 16, color: AppColors.red),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                  '${allergenWarning.join(', ')} 성분이 포함될 수 있습니다.',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.red, height: 1.4),
                )),
              ]),
            ),
          ],
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('추천 이유',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSub)),
            const SizedBox(height: 6),
            Text(reason,
                style: const TextStyle(
                    fontSize: 13.5, color: AppColors.text, height: 1.55)),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// 타이핑 인디케이터
// ──────────────────────────────────────────────
class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _anims;

  static const _statusMessages = ['영양 데이터 검색 중', 'AI가 답변 작성 중', '맞춤 분석 중'];
  int _statusIndex = 0;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
        3,
        (i) => AnimationController(
            vsync: this, duration: const Duration(milliseconds: 600))
          ..repeat(
              reverse: true, period: Duration(milliseconds: 600 + i * 150)));
    _anims = _controllers
        .map((c) => Tween<double>(begin: 0.3, end: 1.0).animate(c))
        .toList();

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return false;
      setState(
          () => _statusIndex = (_statusIndex + 1) % _statusMessages.length);
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
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
                color: AppColors.brandSoft, shape: BoxShape.circle),
            child: const Icon(Icons.smart_toy_outlined,
                size: 16, color: AppColors.brand),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppRadius.md),
                topRight: Radius.circular(AppRadius.md),
                bottomRight: Radius.circular(AppRadius.md),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: AppShadows.card,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              ...List.generate(
                  3,
                  (i) => AnimatedBuilder(
                        animation: _anims[i],
                        builder: (_, __) => Padding(
                          padding: EdgeInsets.only(right: i < 2 ? 4.0 : 0),
                          child: Opacity(
                            opacity: _anims[i].value,
                            child: Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                    color: AppColors.brand,
                                    shape: BoxShape.circle)),
                          ),
                        ),
                      )),
              const SizedBox(width: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _statusMessages[_statusIndex],
                  key: ValueKey(_statusIndex),
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
