import 'package:chatapplication/services/api/api_service.dart';
import 'package:chatapplication/services/cache/media_cache_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/message.dart';
import '../image/enhanced_image_view.dart';
import '../video/enhanced_video_view.dart';
import '../forward/forward_message_screen.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  MessageBubble({super.key, required this.message, required this.isMe});

  final ApiService _apiService = ApiService();
  final MediaCacheService _mediaCacheService = MediaCacheService();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double width = constraints.maxWidth;
        double bubblePadding = width * 0.04;
        double bubbleRadius = width * 0.06;
        double fontSize = width * 0.037;
        return Padding(
          padding: EdgeInsets.symmetric(
            vertical: bubblePadding / 2,
            horizontal: bubblePadding,
          ),
          child: Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe) const SizedBox(width: 8),
              GestureDetector(
                onLongPress: () => _showMessageOptions(context),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18.0,
                      vertical: 12.0,
                    ),
                    decoration: BoxDecoration(
                      gradient:
                          isMe
                              ? const LinearGradient(
                                colors: [
                                  Color(0xFF833ab4),
                                  Color(0xFFfd1d1d),
                                  Color(0xFFfcb045),
                                ], // Instagram gradient
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                              : const LinearGradient(
                                colors: [
                                  Color.fromARGB(255, 107, 113, 116),
                                  Color(0xFF414345),
                                ], // Subtle dark gradient for received
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black..withValues(),//withOpacity(0.07),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(22),
                        topRight: const Radius.circular(22),
                        bottomLeft:
                            isMe
                                ? const Radius.circular(22)
                                : const Radius.circular(8),
                        bottomRight:
                            isMe
                                ? const Radius.circular(8)
                                : const Radius.circular(22),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMessageContent(context),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTimestamp(message.timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: isMe ? Colors.white : Colors.pinkAccent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isMe && message.isRead)
                              const Padding(
                                padding: EdgeInsets.only(left: 4.0),
                                child: Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white70,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMessageOptions(BuildContext context) async {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + size.width,
        position.dy + size.height,
      ),
      items: [
        const PopupMenuItem(value: 'copy', child: Text('Copy')),
        const PopupMenuItem(value: 'forward', child: Text('Forward')),
        if (isMe) const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );

    if (selected == 'copy') {
      _copyMessage(context);
    } else if (selected == 'forward') {
      _forwardMessage(context);
    } else if (selected == 'delete') {
      _deleteMessage(context);
    }
  }

  Future<void> _deleteMessage(BuildContext context) async {
    try {
      bool isDeleted = await _apiService.deleteMessage(message.id);
      if (!isDeleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No Internet! Connect with internet')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting Message: $e')));
    }
  }

  void _copyMessage(BuildContext context) {
    // Copy message content to clipboard
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message copied to clipboard')),
    );
  }

  void _forwardMessage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ForwardMessageScreen(message: message)),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    switch (message.type) {
      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => EnhancedImageView(
                          imageUrl: message.content,
                          messageId: message.id,
                          onDelete: isMe ? () => _deleteMessage(context) : null,
                        ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _mediaCacheService.getImageThumbnail(
                  imageUrl: message.content,
                  width: 200,
                  height: 150,
                  placeholder: (context, child, loadingProgress) {
                    return Container(
                      width: 200,
                      height: 150,
                      child: const Center(
                        child:
                            CircularProgressIndicator(), // Indeterminate progress
                      ),
                    );
                  },
                  errorWidget: (context, url, error) {
                    return Container(
                      width: 200,
                      height: 150,
                      color: Colors.grey[300],
                      child: const Center(child: Icon(Icons.error)),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      case MessageType.video:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => EnhancedVideoView(
                          videoUrl: message.content,
                          messageId: message.id,
                          onDelete: isMe ? () => _deleteMessage(context) : null,
                        ),
                  ),
                );
              },
              child: _mediaCacheService.getVideoThumbnail(
                videoUrl: message.content,
                width: 200,
                height: 150,
              ),
            ),
          ],
        );
      case MessageType.pdf:
        final fileName = message.content.split('/').last;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _mediaCacheService.getPdfThumbnail(
              pdfUrl: message.content,
              fileName: fileName,
              isMe: isMe,
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () async {
              final urlString = message.content;
              final uri = Uri.parse(urlString);
              if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
              }
              },
              child: Text(
                'Open PDF',
                style: TextStyle(
                  color: isMe ? Colors.white70 : Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        );
      case MessageType.file:
        final fileName = message.content.split('/').last;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _mediaCacheService.getFileThumbnail(
              fileUrl: message.content,
              fileName: fileName,
              isMe: isMe,
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () async {
                // Open file URL
                final urlString = message.content;
                final uri = Uri.parse(urlString);
                if (await canLaunchUrl(uri)) {
                   await launchUrl(uri);
                }
              },
              child: Text(
                'Download',
                style: TextStyle(
                  color: isMe ? Colors.white70 : Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        );
      default:
        return Text(
          message.content,
          style: TextStyle(color: isMe ? Colors.white : Colors.black87),
        );
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    print("timestam from chat ${timestamp}");
    final time = TimeOfDay.fromDateTime(timestamp);
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $period';
  }
}
