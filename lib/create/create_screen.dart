// create/create_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../core/app_theme.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final int _maxChars = 280;

  final List<File> _mediaFiles = [];
  String _audience = 'Everyone';
  bool _isPosting = false;

  // Upload progress per file (0.0 → 1.0)
  final List<double> _uploadProgress = [];

  late final AnimationController _progressAnim;

  @override
  void initState() {
    super.initState();
    _progressAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _controller.addListener(() => setState(() {}));
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
  bool get _isEmpty =>
      _controller.text.trim().isEmpty && _mediaFiles.isEmpty;
  bool get _isDirty =>
      _controller.text.trim().isNotEmpty || _mediaFiles.isNotEmpty;
  double get _progress => (_charCount / _maxChars).clamp(0.0, 1.0);

  // ── Discard dialog ────────────────────────────────────────────────────────
  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Discard buzz?',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17)),
        content: const Text(
          'If you leave, your buzz will be discarded.',
          style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
        ),
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

  // ── Media pickers ──────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result != null) {
      setState(() {
        _mediaFiles
            .addAll(result.paths.whereType<String>().map((p) => File(p)));
        _uploadProgress
            .addAll(List.filled(result.paths.length, 0.0));
      });
    }
  }

  Future<void> _pickVideo() async {
    final result =
    await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.single.path != null) {
      setState(() {
        _mediaFiles.add(File(result.files.single.path!));
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

  // ── Upload all media to Firebase Storage ───────────────────────────────────
  Future<List<String>> _uploadMedia(String buzzId) async {
    final urls = <String>[];
    final uid = FirebaseAuth.instance.currentUser!.uid;

    for (int i = 0; i < _mediaFiles.length; i++) {
      final file = _mediaFiles[i];
      final ext = file.path.split('.').last.toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.$ext';

      // Storage path: buzzes/{uid}/{buzzId}/{fileName}
      final ref = FirebaseStorage.instance
          .ref()
          .child('buzzes')
          .child(uid)
          .child(buzzId)
          .child(fileName);

      final uploadTask = ref.putFile(file);

      // Track per-file upload progress
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

  bool _isVideo(String ext) =>
      ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext);

  // ── Audience picker ────────────────────────────────────────────────────────
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
            width: 40,
            height: 4,
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

  // ── Post ───────────────────────────────────────────────────────────────────
  Future<void> _handlePost() async {
    if (_isEmpty || _isOverLimit || _isPosting) return;
    _focusNode.unfocus();
    HapticFeedback.mediumImpact();

    setState(() => _isPosting = true);
    _progressAnim.repeat();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('You must be signed in to post.');

      // 1. Create the Firestore doc first to get an ID for the Storage path
      final docRef =
      FirebaseFirestore.instance.collection('buzzes').doc();

      // 2. Upload media files (if any) and get their download URLs
      List<String> mediaUrls = [];
      if (_mediaFiles.isNotEmpty) {
        mediaUrls = await _uploadMedia(docRef.id);
      }

      // 3. Write the complete document to Firestore
      await docRef.set({
        'uid': user.uid,
        'displayName': user.displayName ?? 'HiVE User',
        'photoUrl': user.photoURL ?? '',
        'text': _controller.text.trim(),
        'audience': _audience,
        'mediaCount': mediaUrls.length,
        'mediaUrls': mediaUrls,        // ✅ real URLs now
        'likes': 0,
        'likedBy': [],
        'comments': 0,
        'commentsCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _progressAnim.stop();
      if (!mounted) return;

      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Text('🐝', style: TextStyle(fontSize: 16)),
              SizedBox(width: 10),
              Text('Buzz posted!',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
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
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
                child: Text(msg,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
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
            Text(
              '$_remaining',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: _ringColor,
              ),
            ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
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
                        : const Text(
                      'Post',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            const Divider(height: 1, color: AppTheme.dividerColor),

            // Upload progress bar (only visible while uploading media)
            if (_isPosting && _mediaFiles.isNotEmpty)
              _buildUploadProgress(),

            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── User row ────────────────────────────────────────────
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
                                          Text(
                                            _audience,
                                            style: const TextStyle(
                                                color: AppTheme.primary,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700),
                                          ),
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
                                  hintText: "What's the buzz?",
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  hintStyle: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // ── Media grid ──────────────────────────────────────────
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

  // ── Upload progress bar ────────────────────────────────────────────────────
  Widget _buildUploadProgress() {
    final total = _uploadProgress.isEmpty
        ? 0.0
        : _uploadProgress.reduce((a, b) => a + b) / _uploadProgress.length;

    return Column(
      children: [
        LinearProgressIndicator(
          value: total,
          backgroundColor: AppTheme.dividerColor,
          valueColor:
          const AlwaysStoppedAnimation<Color>(AppTheme.primary),
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
              Text(
                '${(total * 100).toInt()}%',
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Media grid ─────────────────────────────────────────────────────────────
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

  Widget _mediaThumb(File file, int index,
      {double? width, double? height}) {
    final progress =
    index < _uploadProgress.length ? _uploadProgress[index] : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          SizedBox(
            width: width ?? double.infinity,
            height: height ?? double.infinity,
            child: Image.file(file,
                fit: BoxFit.cover,
                width: width ?? double.infinity,
                height: height ?? double.infinity),
          ),
          // Per-file upload overlay
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
          // Remove button (hidden while posting)
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

  // ── Bottom toolbar ─────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    final imageCount = _mediaFiles.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Attached media strip (shown when images are added) ───────────
        if (imageCount > 0) _buildAttachmentStrip(),

        Container(
          decoration: BoxDecoration(
            color: AppTheme.scaffoldBg,
            border: Border(
                top: BorderSide(color: AppTheme.dividerColor, width: 0.8)),
          ),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 10,
            bottom: MediaQuery.of(context).padding.bottom + 10,
          ),
          child: Row(
            children: [
              // Photo button with count badge
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
                        child: Text(
                          '$imageCount',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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
              _ToolbarIcon(
                  icon: Icons.alternate_email_rounded,
                  label: 'Mention',
                  onTap: () {
                    _controller.text += '@';
                    _controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: _controller.text.length));
                    _focusNode.requestFocus();
                  }),
              const SizedBox(width: 4),
              _ToolbarIcon(
                  icon: Icons.tag_rounded,
                  label: 'Tag',
                  onTap: () {
                    _controller.text += '#';
                    _controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: _controller.text.length));
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

  // ── Horizontal thumbnail strip shown above toolbar ────────────────────────
  Widget _buildAttachmentStrip() {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: AppTheme.surfaceBg,
        border: Border(
          top: BorderSide(color: AppTheme.dividerColor, width: 0.8),
        ),
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
                final progress =
                i < _uploadProgress.length ? _uploadProgress[i] : 0.0;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _mediaFiles[i],
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Upload progress overlay
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
                    // Remove button
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

// ── Toolbar icon button ────────────────────────────────────────────────────────
class _ToolbarIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _ToolbarIcon(
      {required this.icon,
        required this.label,
        required this.onTap,
        this.active = false});

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
              ? Border.all(color: AppTheme.primary.withOpacity(0.5), width: 1)
              : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                color: active ? AppTheme.primary : AppTheme.primary, size: 17),
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