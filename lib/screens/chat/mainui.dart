import 'package:chatapplication/screens/chat/messagebubble.dart';
import 'package:chatapplication/screens/profile/profile_screen.dart';
import 'package:flutter/material.dart';

Widget mainUI(
  BuildContext context,
  widget,
  _isLoading,
  _messages,
  _scrollController,
  _currentUser,
  _isUploading,
  _messageController,
  _handleFileAttachment,
  _sendMessage,
) {
  return LayoutBuilder(
    builder: (context, constraints) {
      double width = constraints.maxWidth;
      double avatarRadius = width * 0.07;
      double fontSizeTitle = width * 0.045;
      double fontSizeSubtitle = width * 0.035;
      double iconSize = width * 0.06;
      double cardPadding = width * 0.03;
      double cardRadius = width * 0.045;
      return Scaffold(
        appBar: AppBar(
          elevation: 2,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF833ab4),
                  Color(0xFFfd1d1d),
                  Color(0xFFfcb045),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage:
                        widget.otherUser.avatarUrl != null
                            ? NetworkImage(widget.otherUser.avatarUrl!)
                            : null,
                    child:
                        widget.otherUser.avatarUrl == null
                            ? Text(
                              widget.otherUser.username[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                            : null,
                  ),
                  if (widget.otherUser.isOnline)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUser.username,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    widget.otherUser.isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          widget.otherUser.isOnline
                              ? Colors.green
                              : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => ProfileScreen(
                          user: widget.otherUser,
                          isCurrentUser: false,
                        ),
                  ),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _messages.isEmpty
                      ? const Center(child: Text('No messages yet'))
                      : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe = message.senderId == _currentUser.id;

                          return MessageBubble(message: message, isMe: isMe);
                        },
                      ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF232526),
                    Color(0xFF414345),
                  ], // Subtle dark gradient
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black..withValues(),   //withOpacity(0.07),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    color: Colors.blueAccent,
                    tooltip: 'Attach file',
                    onPressed: _isUploading ? null : _handleFileAttachment,
                  ),
                  _isUploading
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const SizedBox.shrink(),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Type a message',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 0,
                            ),
                          ),
                          textCapitalization: TextCapitalization.sentences,
                          keyboardType: TextInputType.multiline,
                          maxLines: null,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                        if (_messageController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _messageController.clear(),
                            splashRadius: 16,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: Color(0xFFfd1d1d),
                      ), // Instagram red
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
