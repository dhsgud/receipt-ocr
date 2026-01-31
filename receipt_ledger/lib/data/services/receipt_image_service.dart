import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

/// Service for saving and managing receipt images
class ReceiptImageService {
  static const String _receiptFolder = 'receipts';
  static const String _thumbnailFolder = 'thumbnails';
  static const int _thumbnailWidth = 200;
  static const int _jpegQuality = 85;

  /// Get the receipts directory path
  Future<Directory> _getReceiptsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory('${appDir.path}/$_receiptFolder');
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }
    return receiptsDir;
  }

  /// Get the thumbnails directory path
  Future<Directory> _getThumbnailsDir() async {
    final receiptsDir = await _getReceiptsDir();
    final thumbnailsDir = Directory('${receiptsDir.path}/$_thumbnailFolder');
    if (!await thumbnailsDir.exists()) {
      await thumbnailsDir.create(recursive: true);
    }
    return thumbnailsDir;
  }

  /// Save a receipt image and generate thumbnail
  /// Returns the saved image path, or null if failed
  Future<String?> saveReceiptImage({
    required String transactionId,
    required String sourcePath,
  }) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        debugPrint('ReceiptImageService: Source file does not exist: $sourcePath');
        return null;
      }

      // Get directories
      final receiptsDir = await _getReceiptsDir();
      final thumbnailsDir = await _getThumbnailsDir();

      // Define target paths
      final imagePath = '${receiptsDir.path}/$transactionId.jpg';
      final thumbnailPath = '${thumbnailsDir.path}/$transactionId.jpg';

      // Copy original image
      await sourceFile.copy(imagePath);
      debugPrint('ReceiptImageService: Saved original to $imagePath');

      // Generate thumbnail in background
      await _generateThumbnail(imagePath, thumbnailPath);

      return imagePath;
    } catch (e) {
      debugPrint('ReceiptImageService: Error saving image: $e');
      return null;
    }
  }

  /// Save a receipt image from bytes and generate thumbnail
  /// Returns the saved image path, or null if failed
  Future<String?> saveReceiptImageFromBytes({
    required String transactionId,
    required Uint8List imageBytes,
  }) async {
    try {
      // Get directories
      final receiptsDir = await _getReceiptsDir();
      final thumbnailsDir = await _getThumbnailsDir();

      // Define target paths
      final imagePath = '${receiptsDir.path}/$transactionId.jpg';
      final thumbnailPath = '${thumbnailsDir.path}/$transactionId.jpg';

      // Save original image
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(imageBytes);
      debugPrint('ReceiptImageService: Saved original to $imagePath');

      // Generate thumbnail in background
      await _generateThumbnail(imagePath, thumbnailPath);

      return imagePath;
    } catch (e) {
      debugPrint('ReceiptImageService: Error saving image from bytes: $e');
      return null;
    }
  }

  /// Generate a thumbnail from an image file
  Future<void> _generateThumbnail(String sourcePath, String targetPath) async {
    try {
      final bytes = await File(sourcePath).readAsBytes();
      
      // Decode and resize in isolate for performance
      final thumbnailBytes = await compute(_resizeImage, {
        'bytes': bytes,
        'width': _thumbnailWidth,
        'quality': _jpegQuality,
      });

      if (thumbnailBytes != null) {
        await File(targetPath).writeAsBytes(thumbnailBytes);
        debugPrint('ReceiptImageService: Generated thumbnail at $targetPath');
      }
    } catch (e) {
      debugPrint('ReceiptImageService: Error generating thumbnail: $e');
    }
  }

  /// Get the thumbnail path for a transaction
  Future<String?> getThumbnailPath(String transactionId) async {
    final thumbnailsDir = await _getThumbnailsDir();
    final thumbnailPath = '${thumbnailsDir.path}/$transactionId.jpg';
    final file = File(thumbnailPath);
    if (await file.exists()) {
      return thumbnailPath;
    }
    return null;
  }

  /// Get the original image path for a transaction
  Future<String?> getImagePath(String transactionId) async {
    final receiptsDir = await _getReceiptsDir();
    final imagePath = '${receiptsDir.path}/$transactionId.jpg';
    final file = File(imagePath);
    if (await file.exists()) {
      return imagePath;
    }
    return null;
  }

  /// Check if a receipt image exists for a transaction
  Future<bool> hasReceiptImage(String transactionId) async {
    final path = await getImagePath(transactionId);
    return path != null;
  }

  /// Delete receipt image and thumbnail for a transaction
  Future<void> deleteReceiptImage(String transactionId) async {
    try {
      final receiptsDir = await _getReceiptsDir();
      final thumbnailsDir = await _getThumbnailsDir();

      final imageFile = File('${receiptsDir.path}/$transactionId.jpg');
      final thumbnailFile = File('${thumbnailsDir.path}/$transactionId.jpg');

      if (await imageFile.exists()) {
        await imageFile.delete();
        debugPrint('ReceiptImageService: Deleted image for $transactionId');
      }
      if (await thumbnailFile.exists()) {
        await thumbnailFile.delete();
        debugPrint('ReceiptImageService: Deleted thumbnail for $transactionId');
      }
    } catch (e) {
      debugPrint('ReceiptImageService: Error deleting image: $e');
    }
  }
}

/// Isolate function to resize image
Uint8List? _resizeImage(Map<String, dynamic> params) {
  try {
    final bytes = params['bytes'] as Uint8List;
    final targetWidth = params['width'] as int;
    final quality = params['quality'] as int;

    final image = img.decodeImage(bytes);
    if (image == null) return null;

    // Resize maintaining aspect ratio
    final resized = img.copyResize(image, width: targetWidth);
    
    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  } catch (e) {
    return null;
  }
}
