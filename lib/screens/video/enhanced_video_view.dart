import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class EnhancedVideoView extends StatefulWidget {
  final String videoUrl;
  final bool isGroupMessage;
  final String? messageId;
  final Function? onDelete;

  const EnhancedVideoView({
    super.key, 
    required this.videoUrl, 
    this.isGroupMessage = false,
    this.messageId,
    this.onDelete,
  });

  @override
  State<EnhancedVideoView> createState() => _EnhancedVideoViewState();
}

class _EnhancedVideoViewState extends State<EnhancedVideoView> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _isDownloading = false;
  bool _isDownloaded = false;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _videoPlayerController = VideoPlayerController.network(widget.videoUrl);
    await _videoPlayerController.initialize();
    
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      showControls: true,
      placeholder: const Center(child: CircularProgressIndicator()),
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error: $errorMessage',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
    
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

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
            onPressed: _shareVideo,
            tooltip: 'Share',
          ),
          IconButton(
            icon: Icon(_isDownloaded ? Icons.download_done : Icons.download, size: 26),
            onPressed: _isDownloading ? null : _downloadVideo,
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
        child: _isInitialized
            ? Hero(
                tag: widget.videoUrl,
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
                    child: Chewie(controller: _chewieController!),
                  ),
                ),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Future<void> _shareVideo() async {
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

      // Download the video
      final response = await http.get(Uri.parse(widget.videoUrl));
      final tempDir = await getTemporaryDirectory();
      final fileName = widget.videoUrl.split('/').last;
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
        SnackBar(content: Text('Error sharing video: $e')),
      );
    }
  }

  Future<void> _downloadVideo() async {
    try {
      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission is required to download videos')),
        );
        return;
      }

      setState(() {
        _isDownloading = true;
      });

      // Download the video
      final response = await http.get(Uri.parse(widget.videoUrl));
      final directory = await getExternalStorageDirectory();
      final fileName = 'chat_app_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filePath = '${directory!.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      setState(() {
        _isDownloading = false;
        _isDownloaded = true;
        _localPath = filePath;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video saved to: $filePath')),
      );
    } catch (e) {
      setState(() {
        _isDownloading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading video: $e')),
      );
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Video'),
        content: const Text('Are you sure you want to delete this video?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              widget.onDelete?.call();
              Navigator.pop(context); // Close video viewer
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}