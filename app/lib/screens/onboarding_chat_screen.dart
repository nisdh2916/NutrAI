import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'user_setup_screen.dart';

// ──────────────────────────────────────────────
// 채팅 메시지 모델
// ──────────────────────────────────────────────
enum MessageSender { bot, user }

class ChatMessage {
  final String text;
  final MessageSender sender;
  final List<String>? quickReplies;
  final bool isTyping;

  const ChatMessage({
    required this.text,
    required this.sender,
    this.quickReplies,
    this.isTyping = false,
  });
}

// ──────────────────────────────────────────────
// 온보딩 챗봇 화면
// ──────────────────────────────────────────────
class OnboardingChatScreen extends StatefulWidget {
  const OnboardingChatScreen({super.key});

  @override
  State<OnboardingChatScreen> createState() => _OnboardingChatScreenState();
}

class _OnboardingChatScreenState extends State<OnboardingChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final UserProfile _profile = UserProfile();
  int _step = 0;
  bool _waitingInput = false;
  bool _isTyping = false;

  // 챗봇 대화 스크립트
  static const _script = [
    {
      'text': '안녕하세요! 저는 NutrAI 영양 코치예요 🌿\n맞춤 식단 관리를 시작하기 전에\n몇 가지 여쭤볼게요!',
    },
    {
      'text': '먼저 성함이 어떻게 되세요?',
      'input': 'name',
      'hint': '이름을 입력해주세요',
    },
    {
      'text': '반가워요! 성별을 선택해주세요.',
      'quick': ['남성', '여성'],
    },
    {
      'text': '나이가 어떻게 되세요?',
      'input': 'age',
      'hint': '예: 25',
    },
    {
      'text': '주요 건강 목표를 선택해주세요!',
      'quick': ['다이어트', '체중 유지', '근육 증진', '저염식'],
    },
    {
      'text': '좋아요! 이제 기본 신체 정보를 입력하면\n맞춤 분석을 시작할게요.',
      'final': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runStep(0));
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── 메시지 추가 ──
  void _addMessage(ChatMessage msg) {
    setState(() => _messages.add(msg));
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ── 대화 스텝 실행 ──
  Future<void> _runStep(int idx) async {
    if (idx >= _script.length) return;
    _step = idx;
    final step = _script[idx];

    // 타이핑 인디케이터
    setState(() => _isTyping = true);
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => _isTyping = false);

    // 봇 메시지 추가
    _addMessage(ChatMessage(
      text: step['text'] as String,
      sender: MessageSender.bot,
      quickReplies: step['quick'] as List<String>?,
    ));

    // 입력 대기 여부
    if (step.containsKey('input')) {
      setState(() {
        _waitingInput = true;
      });
      Future.delayed(const Duration(milliseconds: 200), () => _focusNode.requestFocus());
    }

    // 마지막 스텝 → 다음 화면으로
    if (step['final'] == true) {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => UserSetupScreen(profile: _profile),
          ),
        );
      }
    }
  }

  // ── 사용자 응답 처리 ──
  Future<void> _handleInput(String value) async {
    if (value.trim().isEmpty) return;
    _inputController.clear();
    setState(() => _waitingInput = false);
    _focusNode.unfocus();

    _addMessage(ChatMessage(text: value, sender: MessageSender.user));

    // 프로필에 저장
    switch (_step) {
      case 1:
        _profile.name = value.trim();
        break;
      case 3:
        _profile.age = int.tryParse(value.trim());
        break;
    }

    await Future.delayed(const Duration(milliseconds: 400));
    _runStep(_step + 1);
  }

  // ── 빠른 응답 처리 ──
  Future<void> _handleQuickReply(String value) async {
    _addMessage(ChatMessage(text: value, sender: MessageSender.user));

    switch (_step) {
      case 2:
        _profile.gender = value == '남성' ? '남' : '여';
        break;
      case 4:
        _profile.goal = value == '체중 유지' ? '유지' : value;
        break;
    }

    await Future.delayed(const Duration(milliseconds: 400));
    _runStep(_step + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // 메시지 리스트
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == _messages.length) {
                  return _TypingBubble();
                }
                return _buildMessageRow(_messages[index]);
              },
            ),
          ),

          // 빠른 답변 버튼
          if (_messages.isNotEmpty && _messages.last.quickReplies != null)
            _buildQuickReplies(_messages.last.quickReplies!),

          // 입력창
          _buildInputBar(),
        ],
      ),
    );
  }

  void _skipToSetup() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => UserSetupScreen(profile: UserProfile()),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: _BotAvatar(size: 32),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NutrAI 챗봇', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          Text('온라인', style: TextStyle(fontSize: 11, color: AppColors.green400, fontWeight: FontWeight.w400)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _skipToSetup,
          child: const Text(
            '건너뛰기',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.gray400,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Divider(height: 0.5, color: AppColors.border),
      ),
    );
  }

  Widget _buildMessageRow(ChatMessage msg) {
    final isBot = msg.sender == MessageSender.bot;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isBot) ...[
            _BotAvatar(size: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isBot ? AppColors.white : AppColors.green400,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isBot ? 4 : 16),
                  bottomRight: Radius.circular(isBot ? 16 : 4),
                ),
                border: isBot ? Border.all(color: AppColors.border, width: 0.5) : null,
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.55,
                  color: isBot ? AppColors.textPrimary : AppColors.white,
                ),
              ),
            ),
          ),
          if (!isBot) ...[
            const SizedBox(width: 8),
            _UserAvatar(),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickReplies(List<String> replies) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: replies.map((r) => _QuickReplyChip(
          label: r,
          onTap: () => _handleQuickReply(r),
        )).toList(),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _focusNode,
              enabled: _waitingInput,
              onSubmitted: _handleInput,
              style: const TextStyle(fontSize: 13.5),
              decoration: InputDecoration(
                hintText: _waitingInput ? (_script[_step]['hint'] as String? ?? '입력하세요...') : '메시지를 입력하세요...',
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.green400, width: 1.5),
                ),
                filled: true,
                fillColor: _waitingInput ? AppColors.white : AppColors.gray50,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _handleInput(_inputController.text),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _waitingInput ? AppColors.green400 : AppColors.gray100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// 서브 위젯들
// ──────────────────────────────────────────────

class _BotAvatar extends StatelessWidget {
  final double size;
  const _BotAvatar({this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: AppColors.green50,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.green100, width: 1.5),
      ),
      child: Center(
        child: Icon(Icons.smart_toy_outlined, size: size * 0.55, color: AppColors.green800),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: AppColors.green50,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.green100),
      ),
      child: const Center(
        child: Text('나', style: TextStyle(fontSize: 10, color: AppColors.green800, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _QuickReplyChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickReplyChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.green400, width: 1.5),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.green600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true, period: Duration(milliseconds: 600 + i * 150)));

    _animations = _controllers.map((c) => Tween<double>(begin: 0.3, end: 1.0).animate(c)).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _BotAvatar(size: 28),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => AnimatedBuilder(
                animation: _animations[i],
                builder: (_, __) => Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
                  child: Opacity(
                    opacity: _animations[i].value,
                    child: Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.gray200,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }
}
