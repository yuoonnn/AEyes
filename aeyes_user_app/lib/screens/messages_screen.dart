import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import '../services/tts_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({Key? key}) : super(key: key);

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final TTSService _ttsService = TTSService();
  bool _isReading = false;
  int _refreshKey = 0; // Key to force stream refresh

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final date = timestamp is Timestamp ? timestamp.toDate() : DateTime.parse(timestamp.toString());
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
      if (difference.inHours < 24) return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      if (difference.inDays < 7) return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      
      // Format date for older messages
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _markAsRead(String messageId) async {
    try {
      await _databaseService.markMessageAsRead(messageId);
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  Future<void> _readMessage(String content) async {
    if (_isReading || _ttsService.isSpeaking) return;
    
    setState(() => _isReading = true);
    try {
      await _ttsService.speak(content);
      
      // Wait a bit for TTS to start, then reset reading state
      // The actual speaking happens in background
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() => _isReading = false);
      }
      
    } catch (e) {
      print('Error reading message: $e');
      if (mounted) {
        setState(() => _isReading = false);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reading message: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ) ??
        TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        );
    final contentStyle = theme.textTheme.bodyMedium?.copyWith(
          color: isDark ? Colors.grey[300] : Colors.black87,
        ) ??
        TextStyle(
          color: isDark ? Colors.grey[300] : Colors.black87,
          fontSize: 16,
        );

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Message', style: titleStyle),
        content: Text(
          'Are you sure you want to delete this message? This action cannot be undone.',
          style: contentStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _databaseService.deleteMessage(messageId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message deleted'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error deleting message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting message: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAllMessages() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ) ??
        TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        );
    final contentStyle = theme.textTheme.bodyMedium?.copyWith(
          color: isDark ? Colors.grey[300] : Colors.black87,
        ) ??
        TextStyle(
          color: isDark ? Colors.grey[300] : Colors.black87,
          fontSize: 16,
        );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete All Messages', style: titleStyle),
        content: Text(
          'Are you sure you want to delete all messages? This action cannot be undone.',
          style: contentStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final deletedCount = await _databaseService.deleteAllMessagesForUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $deletedCount message${deletedCount != 1 ? 's' : ''}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error deleting all messages: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting messages: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Any additional initialization if needed
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Messages from Guardians'),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _deleteAllMessages,
              tooltip: 'Delete All',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _refreshKey++; // Force stream refresh by changing key
                });
              },
              tooltip: 'Refresh',
            ),
          ],
        ),
      body: StreamBuilder<QuerySnapshot>(
        key: ValueKey(_refreshKey), // Force rebuild when refresh key changes
        stream: _databaseService.getMessagesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.message, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Messages from your guardians will appear here',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final messages = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final doc = messages[index];
              final data = doc.data() as Map<String, dynamic>;
              final messageId = doc.id;
              final content = data['content'] as String? ?? 'No content';
              final messageType = data['message_type'] as String? ?? 'text';
              final direction = data['direction'] as String? ?? '';
              // Handle both bool and int (0/1) for is_read
              final isReadValue = data['is_read'];
              final isRead = isReadValue is bool 
                  ? isReadValue 
                  : (isReadValue is int ? isReadValue != 0 : false);
              final createdAt = data['created_at'];

              // Only show messages from guardians
              if (direction != 'guardian_to_user') {
                return const SizedBox.shrink();
              }

              // Mark as read when displayed
              if (!isRead) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _markAsRead(messageId);
                });
              }

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                elevation: isRead ? 1 : 3,
                color: isRead ? null : Colors.blue.shade50,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isRead ? Colors.grey : Colors.blue,
                    child: Icon(
                      messageType == 'voice' ? Icons.mic : Icons.message,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    messageType == 'voice' ? 'Voice Message' : 'Message from Guardian',
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        content,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestamp(createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isRead)
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          _isReading ? Icons.stop : Icons.volume_up,
                          color: Colors.blue,
                        ),
                        onPressed: _isReading
                            ? null
                            : () => _readMessage(content),
                        tooltip: 'Read aloud',
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _deleteMessage(messageId),
                        tooltip: 'Delete message',
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
      ),
    );
  }
}