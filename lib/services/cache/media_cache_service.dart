import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class MediaCacheService {
  static final MediaCacheService _instance = MediaCacheService._internal();
  final DefaultCacheManager _cacheManager = DefaultCacheManager();

  factory MediaCacheService() {
    return _instance;
  }

  MediaCacheService._internal();

  /// Get file from cache or download it if not available
  Future<File> getFileFromCache(String url) async {
    final fileInfo = await _cacheManager.getFileFromCache(url);
    if (fileInfo != null) {
      // File exists in cache
      return fileInfo.file;
    } else {
      // File not in cache, download it
      final file = await _cacheManager.getSingleFile(url);
      return file;
    }
  }

  /// Get thumbnail widget for an image
  Widget getImageThumbnail({
    required String imageUrl,
    required double width,
    required double height,
    Widget Function(BuildContext, Widget, DownloadProgress)? placeholder,
    Widget Function(BuildContext, String, dynamic)? errorWidget,
  }) {
    return FutureBuilder<File>(
      future: _cacheManager.getSingleFile(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && 
            snapshot.hasData) {
          // Image is cached, show from local file
          return Image.file(
            snapshot.data!,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              if (errorWidget != null) {
                return errorWidget(context, imageUrl, error);
              }
              return _defaultErrorWidget(context, imageUrl, error);
            },
          );
        } else if (snapshot.hasError) {
          // Error loading image
          return errorWidget?.call(
                context, 
                imageUrl, 
                snapshot.error
              ) ?? 
              _defaultErrorWidget(context, imageUrl, snapshot.error);
        } else {
          // Loading image
          return placeholder?.call(
                context, 
                const SizedBox(), 
                DownloadProgress(imageUrl, 0, 0)
              ) ?? 
              _defaultPlaceholder(width, height);
        }
      },
    );
  }

  /// Get video thumbnail widget
  Widget getVideoThumbnail({
    required String videoUrl,
    required double width,
    required double height,
    Widget Function(BuildContext, String, dynamic)? errorWidget,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.play_circle_fill,
            color: Colors.white,
            size: 50,
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              color: Colors.black54,
              child: const Text(
                'Video',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Get PDF thumbnail widget
  Widget getPdfThumbnail({
    required String pdfUrl,
    required String fileName,
    required bool isMe,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.picture_as_pdf,
          color: isMe ? Colors.white : Colors.red,
          size: 24,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            fileName,
            style: TextStyle(
              color: isMe ? Colors.white : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Get file thumbnail widget
  Widget getFileThumbnail({
    required String fileUrl,
    required String fileName,
    required bool isMe,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.insert_drive_file,
          color: isMe ? Colors.white : Colors.black87,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            fileName,
            style: TextStyle(
              color: isMe ? Colors.white : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Clear all cached files
  Future<void> clearCache() async {
    await _cacheManager.emptyCache();
  }

  /// Remove a specific file from cache
  Future<void> removeFile(String url) async {
    await _cacheManager.removeFile(url);
  }

  /// Default placeholder widget
  Widget _defaultPlaceholder(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  /// Default error widget
  Widget _defaultErrorWidget(BuildContext context, String url, dynamic error) {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.error),
      ),
    );
  }
}