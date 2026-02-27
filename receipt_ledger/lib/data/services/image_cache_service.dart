import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Service for caching receipt images locally (no server sync)
class ImageCacheService {
  static const String _cacheFolder = 'image_cache';

  ImageCacheService();

  /// Get the cache directory
  Future<Directory> _getCacheDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/$_cacheFolder');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Get cached image path for a transaction
  Future<String> _getCachedImagePath(String transactionId) async {
    final cacheDir = await _getCacheDir();
    return '${cacheDir.path}/$transactionId.jpg';
  }

  /// Check if image is cached locally
  Future<bool> isImageCached(String transactionId) async {
    final path = await _getCachedImagePath(transactionId);
    return File(path).exists();
  }

  /// Save image to local cache
  Future<String?> cacheImage(String transactionId, String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return null;
      }

      final cachedPath = await _getCachedImagePath(transactionId);
      await sourceFile.copy(cachedPath);
      return cachedPath;
    } catch (e) {
      return null;
    }
  }

  /// Get image path - check local path first, then cache
  Future<String?> getImagePath(String transactionId, [String? localPath]) async {
    // First check if local path exists
    if (localPath != null && localPath.isNotEmpty) {
      final localFile = File(localPath);
      if (await localFile.exists()) {
        return localPath;
      }
    }
    
    // Check cached path
    final cachedPath = await _getCachedImagePath(transactionId);
    if (await File(cachedPath).exists()) {
      return cachedPath;
    }
    
    // No image available
    return null;
  }

  /// Delete cached image
  Future<void> deleteCachedImage(String transactionId) async {
    try {
      final cachedPath = await _getCachedImagePath(transactionId);
      final file = File(cachedPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
    }
  }

  /// Clear all cached images
  Future<void> clearCache() async {
    try {
      final cacheDir = await _getCacheDir();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }
    } catch (e) {
    }
  }
}
