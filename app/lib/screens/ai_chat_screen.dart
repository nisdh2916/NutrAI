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
    _addBotMessage('안녕하세요! NutrAI 영양 코치입니다 🌿\n무엇이 궁금하신가요? 식단 추천, 영양 정보 등 뭐든 물어보세요!');
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _addBotMessage(String text) {
    setState(() => _messages.add(_Message(text: text, isBot: true)));
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
      _messages.add(_Message(text: text, isBot: false));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final user = context.read<AppState>().user;
      final res = await ChatService.sendMessage(
        message: text,
        user: user,
      );
      _addBotMessage(res.answer);
    } catch (e) {
      _addBotMessage('죄송해요, 잠시 서버 연결에 문제가 있어요.\n잠시 후 다시 시도해주세요. 😥');
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
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.green50,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.green100),
            ),
            child: const Icon(Icons.smart_toy_outlined, size: 18, color: AppColors.green800),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.green50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.green100),
                ),
                child: Text(q, style: const TextStyle(fontSize: 12, color: AppColors.green600, fontWeight: FontWeight.w500)),
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
  const _Message({required this.text, required this.isBot});
}

// ──────────────────────────────────────────────
// 말풍선 위젯
// ──────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final _Message message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isBot = message.isBot;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isBot) ...[
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: AppColors.green50, shape: BoxShape.circle, border: Border.all(color: AppColors.green100)),
              child: const Icon(Icons.smart_toy_outlined, size: 15, color: AppColors.green800),
            ),
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
                message.text,
                style: TextStyle(fontSize: 13.5, height: 1.55, color: isBot ? AppColors.textPrimary : Colors.white),
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
  }
}

// ──────────────────────────────────────────────
// 타이핑 인디케이터
// ──────────────────────────────────────────────
class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true, period: Duration(milliseconds: 600 + i * 150)));
    _anims = _controllers.map((c) => Tween<double>(begin: 0.3, end: 1.0).animate(c)).toList();
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
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: AppColors.green50, shape: BoxShape.circle, border: Border.all(color: AppColors.green100)),
            child: const Icon(Icons.smart_toy_outlined, size: 15, color: AppColors.green800),
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
              children: List.generate(3, (i) => AnimatedBuilder(
                animation: _anims[i],
                builder: (_, __) => Padding(
                  padding: EdgeInsets.only(right: i < 2 ? 4.0 : 0),
                  child: Opacity(
                    opacity: _anims[i].value,
                    child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.gray200, shape: BoxShape.circle)),
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
