// chat/hive_chat_screen.dart
// Gemini-powered multi-turn chat with HiVE bee theme

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/app_theme.dart';

// ─── Gemini API Config ────────────────────────────────────────────────────────
const _apiKey   = 'paste niyo api niyo dito mga kupal'; // 🔑 Replace with your Gemini API key
const _model    = 'gemini-2.0-flash';
const _endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey';

const _systemPrompt =
    'You are BeeBot, the friendly AI assistant of the HiVE social app. '
    'You are helpful, fun, and occasionally use bee puns. '
    'Keep responses concise and conversational.';

// ─── Message Model ────────────────────────────────────────────────────────────
class _Message {
  final String text;
  final bool isUser;
  _Message({required this.text, required this.isUser});
}

// ─── Chat Screen ──────────────────────────────────────────────────────────────
class HiveChatScreen extends StatefulWidget {
  const HiveChatScreen({super.key});
  @override
  State<HiveChatScreen> createState() => _HiveChatScreenState();
}

class _HiveChatScreenState extends State<HiveChatScreen> {
  final _inputCtrl   = TextEditingController();
  final _scrollCtrl  = ScrollController();
  final List<_Message> _messages = [];

  // Gemini multi-turn history format
  final List<Map<String, dynamic>> _history = [];

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Greeting message on open
    _messages.add(_Message(
      text: "Hey! 🐝 How are you? I'm BeeBot, your HiVE assistant. What's the buzz?",
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
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

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _loading) return;

    _inputCtrl.clear();

    // Add user message to UI
    setState(() {
      _messages.add(_Message(text: text, isUser: true));
      _loading = true;
    });
    _scrollToBottom();

    // Add to Gemini history (multi-turn)
    _history.add({
      'role': 'user',
      'parts': [{'text': text}],
    });

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'system_instruction': {
            'parts': [{'text': _systemPrompt}]
          },
          'contents': _history,
          'generationConfig': {
            'temperature': 0.85,
            'maxOutputTokens': 512,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['candidates'][0]['content']['parts'][0]['text']
        as String;

        // Add model reply to history for next turn
        _history.add({
          'role': 'model',
          'parts': [{'text': reply}],
        });

        setState(() {
          _messages.add(_Message(text: reply, isUser: false));
          _loading = false;
        });
      } else {
        // Print full error details for debugging
        debugPrint('Gemini API Error: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        _addError('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('Chat exception: $e');
      debugPrint('Stack trace: $stackTrace');
      _addError('Exception: $e');
    }

    _scrollToBottom();
  }

  void _addError(String msg) {
    setState(() {
      _messages.add(_Message(text: msg, isUser: false));
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.cardBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            // Bee avatar
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: const Center(
                child: Text('🐝', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BeeBot',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Row(children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('Online',
                      style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                ]),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: Colors.white54, size: 22),
            onPressed: () {
              setState(() {
                _messages.clear();
                _history.clear();
                _messages.add(_Message(
                  text:
                  "Hey! 🐝 How are you? I'm BeeBot, your HiVE assistant. What's the buzz?",
                  isUser: false,
                ));
              });
            },
          ),
        ],
      ),

      body: Column(
        children: [
          // ── Messages List ────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length + (_loading ? 1 : 0),
              itemBuilder: (context, i) {
                // Typing indicator
                if (_loading && i == _messages.length) {
                  return _TypingIndicator();
                }
                return _ChatBubble(message: _messages[i]);
              },
            ),
          ),

          // ── Input Bar ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            decoration: const BoxDecoration(
              color: AppTheme.cardBg,
              border: Border(
                  top: BorderSide(color: AppTheme.dividerColor, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: 'Ask BeeBot anything...',
                      hintStyle: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 14),
                      filled: true,
                      fillColor: AppTheme.surfaceBg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
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
                  onTap: _sendMessage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _loading
                          ? AppTheme.surfaceBg
                          : AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _loading
                          ? Icons.hourglass_top_rounded
                          : Icons.send_rounded,
                      color: _loading ? Colors.white38 : Colors.black,
                      size: 22,
                    ),
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

// ─── Chat Bubble ──────────────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final _Message message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // BeeBot avatar
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🐝', style: TextStyle(fontSize: 15)),
              ),
            ),
          ],

          // Bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.primary : AppTheme.surfaceBg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: isUser
                    ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
                    : [],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isUser ? Colors.black : Colors.white,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: isUser
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
          ),

          // User avatar placeholder
          if (isUser) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(left: 8),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceBg,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.person_rounded,
                    color: Colors.white54, size: 18),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Typing Indicator ─────────────────────────────────────────────────────────
class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
          (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      )..repeat(
        reverse: true,
        period: Duration(milliseconds: 800 + i * 150),
      ),
    );
    _anims = _controllers
        .map((c) => Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();

    // Stagger the dots
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🐝', style: TextStyle(fontSize: 15)),
            ),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Row(
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _anims[i],
                  builder: (_, __) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 7,
                    height: 7 + _anims[i].value * 4,
                    decoration: BoxDecoration(
                      color: AppTheme.primary
                          .withOpacity(0.5 + _anims[i].value * 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}