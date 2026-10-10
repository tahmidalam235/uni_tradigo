import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// StorageService — converts a picked image into a Base64 data URL so it
/// can be stored directly inside the Firestore listing document.
///
/// We use this approach instead of Firebase Storage so the project works
/// fully on the free Firebase (Spark) plan.
///
/// Returns a `data:image/<ext>;base64,<...>` string that can be passed
/// straight into `Image.network(...)` (it accepts data URLs).
class StorageService {
  /// Reads [file] and returns a Base64 data URL.
  /// Returns null if the file can't be read.
  Future<String?> encodeImageAsBase64(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final ext = file.path.split('.').last.toLowerCase();
      final safeExt = (ext == 'png' || ext == 'webp' || ext == 'gif')
          ? ext
          : 'jpeg';
      final b64 = base64Encode(bytes);
      return 'data:image/$safeExt;base64,$b64';
    } catch (e) {
      debugPrint('StorageService.encodeImageAsBase64 failed: $e');
      return null;
    }
  }
}
