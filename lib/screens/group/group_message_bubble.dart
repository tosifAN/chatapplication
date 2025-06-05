import 'package:chatapplication/screens/image/enhanced_image_view.dart';
import 'package:chatapplication/screens/video/enhanced_video_view.dart';
import 'package:chatapplication/services/api/api_service.dart';
import 'package:chatapplication/util/time.dart';
import 'package:flutter/material.dart';
import 'package:chatapplication/models/message.dart';
import 'package:chatapplication/models/user.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chatapplication/screens/forward/forward_message_screen.dart';

class GroupMessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final User sender;

  GroupMessageBubble({super.key, 
    required this.message,
    required this.isMe,
    required this.sender,
  });

  final ApiService _apiService = ApiService();


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[  
            CircleAvatar(
              radius: 16,
              backgroundImage: sender.avatarUrl != null
                  ? NetworkImage(sender.avatarUrl!)
                  : null,
              child: sender.avatarUrl == null
                  ? Text(sender.username[0].toUpperCase(), style: const TextStyle(fontSize: 12))
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      sender.username,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                GestureDetector(
                  onLongPress: () {
                    _showMessageOptions(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue : Colors.grey[300],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _buildMessageContent(context),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy'),
            onTap: () {
              Navigator.pop(context);
              _copyMessage(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.forward),
            title: const Text('Forward'),
            onTap: () {
              Navigator.pop(context);
              _forwardMessage(context);
            },
          ),
          if (isMe)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(context);
              },
            ),
        ],
      ),
    );
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
                      isGroupMessage: true,
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
                      isGroupMessage: true,
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
                final Uri url = Uri.parse(message.content);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },

              child: Text(
                'Open PDF',
                style: TextStyle(
                  color: isMe ? Colors.white70 : Colors.blue,
                  decoration: TextDecoration.underline,
                  fontSize: 12,
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
                  size: 20,
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
                final Uri url = Uri.parse(message.content);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              child: Text(
                'Download',
                style: TextStyle(
                  color: isMe ? Colors.white70 : Colors.blue,
                  decoration: TextDecoration.underline,
                  fontSize: 12,
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
}