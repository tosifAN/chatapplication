import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chatapplication/services/cache/media_cache_service.dart';

class EnhancedImageView extends StatefulWidget {
  final String imageUrl;
  final bool isGroupMessage;
  final String? messageId;
  final Function? onDelete;

  const EnhancedImageView({
    super.key, 
    required this.imageUrl, 
    this.isGroupMessage = false,
    this.messageId,
    this.onDelete,
  });

  @override
  State<EnhancedImageView> createState() => _EnhancedImageViewState();
}

class _EnhancedImageViewState extends State<EnhancedImageView> {
  bool _isImageLoaded = false;
  bool _isDownloading = false;
  bool _isDownloaded = false;
  String? _localPath;
  final MediaCacheService _mediaCacheService = MediaCacheService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF21CBF3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, size: 26),
            onPressed: _shareImage,
            tooltip: 'Share',
          ),
          IconButton(
            icon: Icon(_isDownloaded ? Icons.download_done : Icons.download, size: 26),
            onPressed: _isDownloading ? null : _downloadImage,
            tooltip: _isDownloaded ? 'Downloaded' : 'Download',
          ),
          if (widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete, size: 26),
              onPressed: () {
                _confirmDelete(context);
              },
              tooltip: 'Delete',
            ),
        ],
      ),
      body: Center(
        child: _isImageLoaded
            ? FutureBuilder<File>(
                future: _mediaCacheService.getFileFromCache(widget.imageUrl),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done && 
                      snapshot.hasData) {
                    return Hero(
                      tag: widget.imageUrl,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: InteractiveViewer(
                            child: Image.file(snapshot.data!),
                          ),
                        ),
                      ),
                    );
                  } else {
                    return const CircularProgressIndicator(color: Colors.white);
                  }
                },
              )
            : FutureBuilder<File>(
                future: _mediaCacheService.getFileFromCache(widget.imageUrl),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done && 
                      snapshot.hasData) {
                    _isImageLoaded = true;
                    _isDownloaded = true;
                    _localPath = snapshot.data!.path;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.file(snapshot.data!),
                    );
                  } else if (snapshot.hasError) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error, color: Colors.white, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load image: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    );
                  } else {
                    return const CircularProgressIndicator(color: Colors.white);
                  }
                },
              ),
      ),
    );
  }

  Future<void> _shareImage() async {
    try {
      // If already downloaded, share the local file
      if (_isDownloaded && _localPath != null) {
        await Share.shareXFiles([XFile(_localPath!)], text: 'Shared from Chat App');
        return;
      }

      setState(() {
        _isDownloading = true;
      });

      // Get the file from cache or download it
      final file = await _mediaCacheService.getFileFromCache(widget.imageUrl);
      
      setState(() {
        _isDownloading = false;
        _isDownloaded = true;
        _localPath = file.path;
      });

      // Share the file
      await Share.shareXFiles([XFile(file.path)], text: 'Shared from Chat App');
    } catch (e) {
      setState(() {
        _isDownloading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing image: $e')),
      );
    }
  }

  Future<void> _downloadImage() async {
    try {
      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission is required to download images')),
        );
        return;
      }

      setState(() {
        _isDownloading = true;
      });

      // Get the file from cache or download it
      final cachedFile = await _mediaCacheService.getFileFromCache(widget.imageUrl);
      
      // Copy to external storage for user access
      final directory = await getExternalStorageDirectory();
      final fileName = 'chat_app_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${directory!.path}/$fileName';
      final file = await cachedFile.copy(filePath);

      setState(() {
        _isDownloading = false;
        _isDownloaded = true;
        _localPath = filePath;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image saved to: $filePath')),
      );
    } catch (e) {
      setState(() {
        _isDownloading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading image: $e')),
      );
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Image'),
        content: const Text('Are you sure you want to delete this image?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              widget.onDelete?.call();
              Navigator.pop(context); // Close image viewer
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}