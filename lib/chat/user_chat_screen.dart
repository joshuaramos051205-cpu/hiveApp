// chat/user_chat_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/app_theme.dart';
import 'chat_service.dart';

class UserChatScreen extends StatefulWidget {
  final String chatId;
  final String title;
  final String otherUserId;

  const UserChatScreen({
    super.key,
    required this.chatId,
    required this.title,
    required this.otherUserId,
  });

  @override
  State<UserChatScreen> createState() => _UserChatScreenState();
}

class _UserChatScreenState extends State<UserChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    // Mark chat as read when opened
    ChatService.markChatRead(widget.chatId);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await ChatService.sendMessage(
      chatId: widget.chatId,
      text: text,
      otherUserId: widget.otherUserId,
    );
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: AppTheme.primary, width: 1.5),
                color: AppTheme.surfaceBg,
              ),
              child: Center(
                child: Text(
                  widget.title.isNotEmpty
                      ? widget.title[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const Text(
                  'HiVE member',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Messages ────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder(
              stream: ChatService.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.primary),
                  );
                }

                final docs = snapshot.data!.docs;

                // Auto-scroll to bottom on new message
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🐝',
                            style: TextStyle(fontSize: 36)),
                        const SizedBox(height: 12),
                        Text(
                          'Say hi to ${widget.title}!',
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final isMe = data['senderId'] == myUid;
                    final text = (data['text'] ?? '').toString();
                    final isFirst = index == 0 ||
                        docs[index - 1].data()['senderId'] !=
                            data['senderId'];
                    final isLast = index == docs.length - 1 ||
                        docs[index + 1].data()['senderId'] !=
                            data['senderId'];

                    return _MessageBubble(
                      text: text,
                      isMe: isMe,
                      isFirst: isFirst,
                      isLast: isLast,
                    );
                  },
                );
              },
            ),
          ),

          // ── Input ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            decoration: const BoxDecoration(
              color: AppTheme.cardBg,
              border: Border(
                top: BorderSide(color: AppTheme.dividerColor, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (_) => _send(),
                    textInputAction: TextInputAction.send,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Message...',
                      hintStyle: const TextStyle(
                          color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.surfaceBg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                            color: AppTheme.primary, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.black, size: 20),
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

// ─── Message Bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final bool isFirst;
  final bool isLast;

  const _MessageBubble({
    required this.text,
    required this.isMe,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    // Grouped bubbles — only show spacing above first in a group
    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 8 : 2,
        bottom: isLast ? 2 : 0,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && isLast)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 6, bottom: 2),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceBg,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.person_rounded,
                    color: Colors.white54, size: 16),
              ),
            )
          else if (!isMe)
            const SizedBox(width: 34),
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.68,
              ),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primary : AppTheme.surfaceBg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(
                      isMe ? 18 : (isLast ? 4 : 18)),
                  bottomRight: Radius.circular(
                      isMe ? (isLast ? 4 : 18) : 18),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isMe ? Colors.black : Colors.white,
                  fontSize: 14,
                  fontWeight:
                      isMe ? FontWeight.w600 : FontWeight.w400,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
