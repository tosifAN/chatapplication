import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareImage,
            tooltip: 'Share',
          ),
          IconButton(
            icon: Icon(_isDownloaded ? Icons.download_done : Icons.download),
            onPressed: _isDownloading ? null : _downloadImage,
            tooltip: _isDownloaded ? 'Downloaded' : 'Download',
          ),
          if (widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                _confirmDelete(context);
              },
              tooltip: 'Delete',
            ),
        ],
      ),
      body: Center(
        child: _isImageLoaded
            ? InteractiveViewer(
                child: Image.network(widget.imageUrl),
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                  Image.network(
                    widget.imageUrl,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        _isImageLoaded = true;
                        return child;
                      }
                      return const CircularProgressIndicator(color: Colors.white);
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error, color: Colors.white, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      );
                    },
                  ),
                  if (!_isImageLoaded)
                    const CircularProgressIndicator(color: Colors.white),
                ],
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

      // Otherwise download and share
      setState(() {
        _isDownloading = true;
      });

      // Download the image
      final response = await http.get(Uri.parse(widget.imageUrl));
      final tempDir = await getTemporaryDirectory();
      final fileName = widget.imageUrl.split('/').last;
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);

      setState(() {
        _isDownloading = false;
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

      // Download the image
      final response = await http.get(Uri.parse(widget.imageUrl));
      final directory = await getExternalStorageDirectory();
      final fileName = 'chat_app_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${directory!.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

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