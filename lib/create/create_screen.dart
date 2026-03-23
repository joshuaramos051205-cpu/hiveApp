// create/create_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../core/app_theme.dart';
import '../social/notification_service.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final int _maxChars = 280;

  final List<PlatformFile> _mediaFiles = [];
  String _audience = 'Everyone';
  bool _isPosting = false;
  final List<double> _uploadProgress = [];

  // @mention suggestion state
  List<Map<String, dynamic>> _mentionSuggestions = [];
  bool _showSuggestions = false;

  late final AnimationController _progressAnim;

  @override
  void initState() {
    super.initState();
    _progressAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _progressAnim.dispose();
    super.dispose();
  }

  // ── Computed ──────────────────────────────────────────────────────────────
  int get _charCount => _controller.text.length;
  int get _remaining => _maxChars - _charCount;
  bool get _isOverLimit => _remaining < 0;
  bool get _isEmpty => _controller.text.trim().isEmpty && _mediaFiles.isEmpty;
  bool get _isDirty =>
      _controller.text.trim().isNotEmpty || _mediaFiles.isNotEmpty;
  double get _progress => (_charCount / _maxChars).clamp(0.0, 1.0);

  // ── @mention suggestion logic ─────────────────────────────────────────────
  void _onTextChanged() {
    setState(() {}); // rebuild for char count + highlighting

    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) {
      _hideSuggestions();
      return;
    }

    // Find if cursor is right after an @word
    final before = text.substring(0, cursor);
    final match = RegExp(r'@(\w*)$').firstMatch(before);

    if (match != null) {
      final query = match.group(1)!;
      _searchUsers(query);
    } else {
      _hideSuggestions();
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      // Show recent/all users when just "@" is typed
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .limit(5)
          .get();
      final myUid = FirebaseAuth.instance.currentUser?.uid;
      final results = snap.docs
          .where((d) => d.id != myUid)
          .map((d) => {'uid': d.id, 'name': d['name'] ?? 'User'})
          .toList();
      if (mounted) setState(() { _mentionSuggestions = results; _showSuggestions = results.isNotEmpty; });
      return;
    }

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(5)
        .get();

    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final results = snap.docs
        .where((d) => d.id != myUid)
        .map((d) => {'uid': d.id, 'name': d['name'] ?? 'User'})
        .toList();

    if (mounted) {
      setState(() {
        _mentionSuggestions = results;
        _showSuggestions = results.isNotEmpty;
      });
    }
  }

  void _hideSuggestions() {
    if (_showSuggestions || _mentionSuggestions.isNotEmpty) {
      setState(() { _showSuggestions = false; _mentionSuggestions = []; });
    }
  }

  // Insert the selected mention into the text
  void _insertMention(String name) {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    if (cursor < 0) return;

    final before = text.substring(0, cursor);
    final after = text.substring(cursor);

    // Replace the partial @word with the full @name
    final newBefore = before.replaceAllMapped(
      RegExp(r'@(\w*)$'),
      (_) => '@$name ',
    );

    _controller.value = TextEditingValue(
      text: '$newBefore$after',
      selection: TextSelection.collapsed(offset: newBefore.length),
    );
    _hideSuggestions();
    _focusNode.requestFocus();
  }

  // ── Discard dialog ────────────────────────────────────────────────────────
  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Discard buzz?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
        content: const Text('If you leave, your buzz will be discarded.',
            style: TextStyle(
                color: AppTheme.textSecondary, fontSize: 14, height: 1.5)),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Discard',
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Keep editing',
                  style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Media pickers ─────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (result != null) {
      setState(() {
        _mediaFiles.addAll(result.files);
        _uploadProgress.addAll(List.filled(result.files.length, 0.0));
      });
    }
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: kIsWeb,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _mediaFiles.add(result.files.single);
        _uploadProgress.add(0.0);
      });
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _mediaFiles.removeAt(index);
      _uploadProgress.removeAt(index);
    });
  }

  // ── Upload media ──────────────────────────────────────────────────────────
  Future<List<String>> _uploadMedia(String buzzId) async {
    final urls = <String>[];
    final uid = FirebaseAuth.instance.currentUser!.uid;

    for (int i = 0; i < _mediaFiles.length; i++) {
      final pf = _mediaFiles[i];
      final ext = (pf.extension ?? 'jpg').toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.$ext';

      final ref = FirebaseStorage.instance
          .ref()
          .child('buzzes')
          .child(uid)
          .child(buzzId)
          .child(fileName);

      UploadTask uploadTask;

      if (kIsWeb || pf.bytes != null) {
        final bytes = pf.bytes ?? await File(pf.path!).readAsBytes();
        uploadTask = ref.putData(bytes,
            SettableMetadata(contentType: _mimeType(ext)));
      } else {
        uploadTask = ref.putFile(File(pf.path!));
      }

      uploadTask.snapshotEvents.listen((snap) {
        final progress =
            snap.bytesTransferred / (snap.totalBytes == 0 ? 1 : snap.totalBytes);
        if (mounted) {
          setState(() {
            if (i < _uploadProgress.length) _uploadProgress[i] = progress;
          });
        }
      });

      await uploadTask;
      final url = await ref.getDownloadURL();
      urls.add(url);
    }

    return urls;
  }

  String _mimeType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png':  return 'image/png';
      case 'gif':  return 'image/gif';
      case 'webp': return 'image/webp';
      case 'mp4':  return 'video/mp4';
      case 'mov':  return 'video/quicktime';
      case 'webm': return 'video/webm';
      default:     return 'application/octet-stream';
    }
  }

  bool _isVideo(String ext) =>
      ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext);

  // ── Audience picker ───────────────────────────────────────────────────────
  void _showAudiencePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 20, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Who can see this buzz?',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ),
          ),
          for (final option in ['Everyone', 'Followers', 'Only me'])
            ListTile(
              leading: Icon(
                option == 'Everyone'
                    ? Icons.public_rounded
                    : option == 'Followers'
                        ? Icons.people_rounded
                        : Icons.lock_rounded,
                color: _audience == option
                    ? AppTheme.primary
                    : Colors.white54,
              ),
              title: Text(option,
                  style: TextStyle(
                      color: _audience == option
                          ? AppTheme.primary
                          : Colors.white,
                      fontWeight: FontWeight.w600)),
              trailing: _audience == option
                  ? const Icon(Icons.check_rounded, color: AppTheme.primary)
                  : null,
              onTap: () {
                setState(() => _audience = option);
                Navigator.pop(context);
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Post ──────────────────────────────────────────────────────────────────
  Future<void> _handlePost() async {
    if (_isEmpty || _isOverLimit || _isPosting) return;
    _focusNode.unfocus();
    _hideSuggestions();
    HapticFeedback.mediumImpact();

    setState(() => _isPosting = true);
    _progressAnim.repeat();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('You must be signed in to post.');

      final docRef = FirebaseFirestore.instance.collection('buzzes').doc();

      List<String> mediaUrls = [];
      if (_mediaFiles.isNotEmpty) {
        mediaUrls = await _uploadMedia(docRef.id);
      }

      final captionText = _controller.text.trim();

      await docRef.set({
        'uid': user.uid,
        'displayName': user.displayName ?? 'HiVE User',
        'photoUrl': user.photoURL ?? '',
        'text': captionText,
        'audience': _audience,
        'mediaCount': mediaUrls.length,
        'mediaUrls': mediaUrls,
        'likes': 0,
        'likedBy': [],
        'comments': 0,
        'commentsCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ── Send @mention notifications after post is saved ────────────────
      await NotificationService.sendMentionNotifications(
        text: captionText,
        postId: docRef.id,
        postImageUrl: mediaUrls.isNotEmpty ? mediaUrls.first : null,
      );

      _progressAnim.stop();
      if (!mounted) return;

      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Text('🐝', style: TextStyle(fontSize: 16)),
            SizedBox(width: 10),
            Text('Buzz posted!',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
          backgroundColor: const Color(0xFF1E1E1E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.of(context).pop(true);
    } on FirebaseException catch (e) {
      _progressAnim.stop();
      _showError(e.message ?? 'Something went wrong. Try again.');
    } catch (e) {
      _progressAnim.stop();
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w500))),
        ]),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ── Char ring ─────────────────────────────────────────────────────────────
  Color get _ringColor {
    if (_isOverLimit) return Colors.redAccent;
    if (_remaining < 20) return Colors.orangeAccent;
    return AppTheme.primary;
  }

  Widget _buildCharRing() {
    return SizedBox(
      width: 26,
      height: 26,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: _progress,
            strokeWidth: 2.5,
            backgroundColor: AppTheme.dividerColor,
            valueColor: AlwaysStoppedAnimation(_ringColor),
          ),
          if (_remaining <= 20)
            Text('$_remaining',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _ringColor)),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return WillPopScope(
      onWillPop: _confirmDiscard,
      child: Scaffold(
        backgroundColor: AppTheme.scaffoldBg,
        appBar: AppBar(
          backgroundColor: AppTheme.scaffoldBg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded,
                color: Colors.white, size: 26),
            onPressed: () async {
              if (await _confirmDiscard()) Navigator.of(context).pop();
            },
          ),
          title: const Text('New Buzz',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isEmpty || _isOverLimit ? 0.4 : 1.0,
                child: GestureDetector(
                  onTap: _isEmpty || _isOverLimit || _isPosting
                      ? null
                      : _handlePost,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: _isPosting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black87),
                          )
                        : const Text('Post',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            )),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            const Divider(height: 1, color: AppTheme.dividerColor),

            if (_isPosting && _mediaFiles.isNotEmpty)
              _buildUploadProgress(),

            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_isPosting)
                              AnimatedBuilder(
                                animation: _progressAnim,
                                builder: (_, __) => SizedBox(
                                  width: 54,
                                  height: 54,
                                  child: CircularProgressIndicator(
                                    value: _progressAnim.value,
                                    strokeWidth: 2,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              )
                            else
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppTheme.primary, width: 2),
                                ),
                              ),
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppTheme.surfaceBg,
                              backgroundImage: user?.photoURL != null
                                  ? NetworkImage(user!.photoURL!)
                                  : null,
                              child: user?.photoURL == null
                                  ? const Text('🐝',
                                      style: TextStyle(fontSize: 20))
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    user?.displayName ?? 'HiVE User',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: _showAudiencePicker,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary
                                            .withOpacity(0.15),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                            color: AppTheme.primary
                                                .withOpacity(0.4),
                                            width: 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(_audience,
                                              style: const TextStyle(
                                                  color: AppTheme.primary,
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.w700)),
                                          const SizedBox(width: 3),
                                          const Icon(
                                              Icons
                                                  .keyboard_arrow_down_rounded,
                                              color: AppTheme.primary,
                                              size: 13),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // ── TextField with @mention + #tag highlighting
                              TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                maxLines: null,
                                autofocus: true,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    height: 1.5),
                                decoration: const InputDecoration(
                                  hintText: "What's the buzz? Use @ to mention",
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  hintStyle: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 16,
                                  ),
                                ),
                              ),

                              // ── @mention text preview with colors ─────────
                              if (_controller.text.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: _MentionPreview(
                                      text: _controller.text),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // ── @mention suggestions dropdown ─────────────────────
                    if (_showSuggestions && _mentionSuggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8, left: 54),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: AppTheme.dividerColor),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _mentionSuggestions.map((u) {
                            final name = u['name'] as String;
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: AppTheme.surfaceBg,
                                child: Text(
                                  name.isNotEmpty
                                      ? name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12),
                                ),
                              ),
                              title: Text('@$name',
                                  style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                              onTap: () => _insertMention(name),
                            );
                          }).toList(),
                        ),
                      ),

                    if (_mediaFiles.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildMediaGrid(),
                    ],

                    SizedBox(height: bottomInset + 80),
                  ],
                ),
              ),
            ),

            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ── Upload progress bar ───────────────────────────────────────────────────
  Widget _buildUploadProgress() {
    final total = _uploadProgress.isEmpty
        ? 0.0
        : _uploadProgress.reduce((a, b) => a + b) / _uploadProgress.length;

    return Column(
      children: [
        LinearProgressIndicator(
          value: total,
          backgroundColor: AppTheme.dividerColor,
          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
          minHeight: 2,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                _mediaFiles.length == 1
                    ? 'Uploading photo...'
                    : 'Uploading ${_mediaFiles.length} files...',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
              ),
              const Spacer(),
              Text('${(total * 100).toInt()}%',
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Media grid ────────────────────────────────────────────────────────────
  Widget _buildMediaGrid() {
    final count = _mediaFiles.length;

    if (count == 1) {
      return _mediaThumb(_mediaFiles[0], 0,
          width: double.infinity, height: 260);
    }
    if (count == 2) {
      return Row(children: [
        Expanded(child: _mediaThumb(_mediaFiles[0], 0, height: 180)),
        const SizedBox(width: 3),
        Expanded(child: _mediaThumb(_mediaFiles[1], 1, height: 180)),
      ]);
    }
    if (count == 3) {
      return Row(children: [
        Expanded(
            flex: 2,
            child: _mediaThumb(_mediaFiles[0], 0, height: 200)),
        const SizedBox(width: 3),
        Expanded(
          child: Column(children: [
            _mediaThumb(_mediaFiles[1], 1, height: 98),
            const SizedBox(height: 3),
            _mediaThumb(_mediaFiles[2], 2, height: 98),
          ]),
        ),
      ]);
    }

    final show = _mediaFiles.take(4).toList();
    final extra = count - 4;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 3,
      mainAxisSpacing: 3,
      children: List.generate(show.length, (i) {
        final isLast = i == 3 && extra > 0;
        return Stack(fit: StackFit.expand, children: [
          _mediaThumb(show[i], i),
          if (isLast)
            Container(
              decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: Text('+$extra',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
            ),
        ]);
      }),
    );
  }

  Widget _mediaThumb(PlatformFile pf, int index,
      {double? width, double? height}) {
    final progress =
        index < _uploadProgress.length ? _uploadProgress[index] : 0.0;

    Widget imageWidget;
    if (kIsWeb || pf.bytes != null) {
      final bytes = pf.bytes;
      imageWidget = bytes != null
          ? Image.memory(bytes,
              fit: BoxFit.cover,
              width: width ?? double.infinity,
              height: height ?? double.infinity)
          : Container(color: AppTheme.surfaceBg);
    } else {
      imageWidget = Image.file(File(pf.path!),
          fit: BoxFit.cover,
          width: width ?? double.infinity,
          height: height ?? double.infinity);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          SizedBox(
            width: width ?? double.infinity,
            height: height ?? double.infinity,
            child: imageWidget,
          ),
          if (_isPosting && progress < 1.0)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                alignment: Alignment.center,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    color: AppTheme.primary,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
            ),
          if (!_isPosting)
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: () => _removeMedia(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Bottom toolbar ────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    final imageCount = _mediaFiles.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (imageCount > 0) _buildAttachmentStrip(),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.scaffoldBg,
            border: Border(
                top: BorderSide(
                    color: AppTheme.dividerColor, width: 0.8)),
          ),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 10,
            bottom: MediaQuery.of(context).padding.bottom + 10,
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _ToolbarIcon(
                    icon: imageCount > 0
                        ? Icons.image_rounded
                        : Icons.image_outlined,
                    label: 'Photo',
                    active: imageCount > 0,
                    onTap: _isPosting ? () {} : _pickImage,
                  ),
                  if (imageCount > 0)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppTheme.scaffoldBg, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text('$imageCount',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            )),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 4),
              _ToolbarIcon(
                  icon: Icons.video_camera_back_outlined,
                  label: 'Video',
                  onTap: _isPosting ? () {} : _pickVideo),
              const SizedBox(width: 4),
              // Mention button — inserts @ and triggers suggestion
              _ToolbarIcon(
                  icon: Icons.alternate_email_rounded,
                  label: 'Mention',
                  onTap: () {
                    _controller.text += '@';
                    _controller.selection = TextSelection.collapsed(
                        offset: _controller.text.length);
                    _focusNode.requestFocus();
                  }),
              const SizedBox(width: 4),
              _ToolbarIcon(
                  icon: Icons.tag_rounded,
                  label: 'Tag',
                  onTap: () {
                    _controller.text += '#';
                    _controller.selection = TextSelection.collapsed(
                        offset: _controller.text.length);
                    _focusNode.requestFocus();
                  }),
              const Spacer(),
              _buildCharRing(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Attachment strip ──────────────────────────────────────────────────────
  Widget _buildAttachmentStrip() {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: AppTheme.surfaceBg,
        border: Border(
            top: BorderSide(color: AppTheme.dividerColor, width: 0.8)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.attach_file_rounded,
              color: AppTheme.primary, size: 16),
          const SizedBox(width: 6),
          Text(
            '${_mediaFiles.length} attachment${_mediaFiles.length > 1 ? 's' : ''}',
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _mediaFiles.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final pf = _mediaFiles[i];
                final progress =
                    i < _uploadProgress.length ? _uploadProgress[i] : 0.0;

                Widget thumb;
                if (kIsWeb || pf.bytes != null) {
                  final bytes = pf.bytes;
                  thumb = bytes != null
                      ? Image.memory(bytes,
                          width: 52, height: 52, fit: BoxFit.cover)
                      : Container(
                          width: 52,
                          height: 52,
                          color: AppTheme.surfaceBg);
                } else {
                  thumb = Image.file(File(pf.path!),
                      width: 52, height: 52, fit: BoxFit.cover);
                }

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: thumb),
                    if (_isPosting && progress < 1.0)
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 2.5,
                            color: AppTheme.primary,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                      ),
                    if (!_isPosting)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _removeMedia(i),
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 10),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

// ─── Mention Preview — shows colored @mentions and #tags ─────────────────────
// Displayed below the TextField as a read-only preview.

class _MentionPreview extends StatelessWidget {
  final String text;
  const _MentionPreview({required this.text});

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'(@\w+|#\w+)');
    int last = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(
          text: text.substring(last, match.start),
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ));
      }
      final token = match.group(0)!;
      final isMention = token.startsWith('@');
      spans.add(TextSpan(
        text: token,
        style: TextStyle(
          color: isMention ? AppTheme.primary : const Color(0xFF4FC3F7),
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ));
      last = match.end;
    }

    if (last < text.length) {
      spans.add(TextSpan(
        text: text.substring(last),
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ));
    }

    if (spans.every((s) =>
        s.style?.color == const Color(0xFFFFFFFF) ||
        s.style?.color == Colors.white70)) {
      return const SizedBox.shrink(); // no highlights, don't show preview
    }

    return RichText(text: TextSpan(children: spans));
  }
}

// ─── Toolbar Icon ─────────────────────────────────────────────────────────────

class _ToolbarIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _ToolbarIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primary.withOpacity(0.15)
              : AppTheme.surfaceBg,
          borderRadius: BorderRadius.circular(20),
          border: active
              ? Border.all(
                  color: AppTheme.primary.withOpacity(0.5), width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                color: AppTheme.primary, size: 17),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: active ? AppTheme.primary : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}