// feed/upload_notifier.dart
//
// Global singleton na nagtatago ng upload state.
// Ginagamit ng FeedService para mag-update ng progress,
// at ng FeedScreen para mag-show ng banner.

import 'package:flutter/foundation.dart';

enum UploadStatus { idle, uploading, done, error }

class UploadNotifier extends ChangeNotifier {
  // Singleton
  static final UploadNotifier instance = UploadNotifier._();
  UploadNotifier._();

  UploadStatus _status = UploadStatus.idle;
  double _progress = 0.0; // 0.0 → 1.0
  String _label = '';

  UploadStatus get status => _status;
  double get progress => _progress;
  String get label => _label;

  bool get isUploading => _status == UploadStatus.uploading;

  void start(String label) {
    _status = UploadStatus.uploading;
    _progress = 0.0;
    _label = label;
    notifyListeners();
  }

  void updateProgress(double value) {
    _progress = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void finish() {
    _status = UploadStatus.done;
    _progress = 1.0;
    notifyListeners();
    // Auto-reset after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      _status = UploadStatus.idle;
      _progress = 0.0;
      _label = '';
      notifyListeners();
    });
  }

  void fail() {
    _status = UploadStatus.error;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 3000), () {
      _status = UploadStatus.idle;
      _progress = 0.0;
      _label = '';
      notifyListeners();
    });
  }

  void reset() {
    _status = UploadStatus.idle;
    _progress = 0.0;
    _label = '';
    notifyListeners();
  }
}
