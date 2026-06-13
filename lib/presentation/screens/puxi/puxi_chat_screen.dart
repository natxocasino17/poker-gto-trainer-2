import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/utils/puxi_knowledge.dart';
import '../../widgets/zeros_avatar.dart';

/// Offline AI coach chat. el Puxi answers poker fundamentals questions
/// from a curated knowledge base — works with no internet, fully free.
class PuxiChatScreen extends StatefulWidget {
  const PuxiChatScreen({super.key});

  @override
  State<PuxiChatScreen> createState() => _PuxiChatScreenState();
}

class _ChatMsg {
  final String text;
  final bool fromPuxi;
  _ChatMsg(this.text, this.fromPuxi);
}

class _PuxiChatScreenState extends State<PuxiChatScreen> {
  final List<_ChatMsg> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMsg(I18n.t('puxi_greeting'), true));
  }

  void _send(String text) {
    final q = text.trim();
    if (q.isEmpty) return;
    setState(() {
      _messages.add(_ChatMsg(q, false));
      final topic = PuxiKnowledge.match(q);
      _messages.add(_ChatMsg(
        topic != null ? topic.localizedAnswer : I18n.t('puxi_no_match'),
        true,
      ));
    });
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ZerosAvatar(size: 28),
            const SizedBox(width: 8),
            Text(I18n.t('puxi_chat')),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(14),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _Bubble(msg: _messages[i]),
            ),
          ),
          // Topic suggestion chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                for (final t in PuxiKnowledge.topics)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      backgroundColor: AppColors.surfaceElevated,
                      side: BorderSide(color: AppColors.accent.withOpacity(0.4)),
                      label: Text(t.title,
                          style: const TextStyle(color: AppColors.accent, fontSize: 12)),
                      onPressed: () => _send(t.keywords.first),
                    ),
                  ),
              ],
            ),
          ),
          // Input bar
          Container(
            padding: EdgeInsets.only(
              left: 12, right: 8, top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    decoration: InputDecoration(
                      hintText: I18n.t('ask_placeholder'),
                      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.accent),
                  onPressed: () => _send(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final _ChatMsg msg;
  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final fromPuxi = msg.fromPuxi;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: fromPuxi ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fromPuxi) ...[
            const ZerosAvatar(size: 30),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: fromPuxi ? AppColors.card : AppColors.accent.withOpacity(0.18),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(fromPuxi ? 2 : 14),
                  bottomRight: Radius.circular(fromPuxi ? 14 : 2),
                ),
                border: Border.all(
                  color: fromPuxi ? AppColors.border : AppColors.accent.withOpacity(0.4),
                ),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: fromPuxi ? AppColors.textSecondary : AppColors.textPrimary,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
