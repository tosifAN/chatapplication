import 'package:chatapplication/services/api/api_service.dart';
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

  MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  final ApiService _apiService = ApiService();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
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
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? const LinearGradient(
                          colors: [Color(0xFF2196F3), Color(0xFF21CBF3)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFE0E0E0), Color(0xFFF5F5F5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
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
                            color: isMe ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                        if (isMe && message.isRead)
                          const Padding(
                            padding: EdgeInsets.only(left: 4.0),
                            child: Icon(Icons.check, size: 14, color: Colors.white70),
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
        if (isMe)
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
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
          await _apiService.deleteMessage(message.id);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Message deleted successfully')),
          );
          } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error deleting Message: $e')),
              );
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
      MaterialPageRoute(
        builder: (_) => ForwardMessageScreen(message: message),
      ),
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
                    builder: (_) => EnhancedImageView(
                      imageUrl: message.content,
                      messageId: message.id,
                      onDelete: isMe ? () => _deleteMessage(context) : null,
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  message.content,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 200,
                      height: 150,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 200,
                      height: 150,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.error),
                      ),
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
                    builder: (_) => EnhancedVideoView(
                      videoUrl: message.content,
                      messageId: message.id,
                      onDelete: isMe ? () => _deleteMessage(context) : null,
                    ),
                  ),
                );
              },
              child: Container(
                width: 200,
                height: 150,
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
                        child: Text(
                          'Video',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      case MessageType.pdf:
        final fileName = message.content.split('/').last;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () async {
                // Open PDF in external viewer
                final url = message.content;
                if (await canLaunch(url)) {
                  await launch(url);
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
            Row(
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
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () async {
                // Open file URL
                final url = message.content;
                if (await canLaunch(url)) {
                  await launch(url);
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
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
          ),
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
