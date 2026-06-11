import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

enum CameraPermissionResult {
  granted,
  denied,
  permanentlyDenied,
}

class ScannerService {
  final ImagePicker _picker = ImagePicker();

  /// Request camera permission. Returns detailed result.
  Future<CameraPermissionResult> requestCameraPermission() async {
    if (Platform.isMacOS) {
      // macOS handles camera permissions natively via App Sandbox entitlements.
      // permission_handler is not fully supported on macOS and throws MissingPluginException.
      return CameraPermissionResult.granted;
    }
    
    final status = await Permission.camera.request();
    if (status.isGranted) {
      return CameraPermissionResult.granted;
    } else if (status.isPermanentlyDenied) {
      return CameraPermissionResult.permanentlyDenied;
    } else {
      return CameraPermissionResult.denied;
    }
  }

  /// Open app settings so user can grant camera permission
  Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// Pick single image from gallery
  Future<String?> pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );
      return photo?.path;
    } catch (e) {
      debugPrint('Gallery picker failed: $e');
      return null;
    }
  }

  /// Pick multiple images from gallery
  Future<List<String>?> pickMultipleFromGallery() async {
    try {
      final List<XFile> photos = await _picker.pickMultiImage(
        imageQuality: 95,
      );
      if (photos.isNotEmpty) {
        return photos.map((x) => x.path).toList();
      }
      return null;
    } catch (e) {
      debugPrint('Gallery picker failed: $e');
      return null;
    }
  }
}
