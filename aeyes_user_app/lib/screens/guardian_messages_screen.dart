import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class GuardianMessagesScreen extends StatefulWidget {
  const GuardianMessagesScreen({Key? key}) : super(key: key);

  @override
  State<GuardianMessagesScreen> createState() => _GuardianMessagesScreenState();
}

class _GuardianMessagesScreenState extends State<GuardianMessagesScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<String> _linkedUserIds = [];
  bool _isLoadingUsers = true;
  
  @override
  void initState() {
    super.initState();
    _loadLinkedUsers();
  }
  
  Future<void> _loadLinkedUsers() async {
    try {
      final user = _auth.currentUser;
      if (user?.email == null) {
        setState(() => _isLoadingUsers = false);
        return;
      }
      
      final normalizedEmail = user!.email!.trim().toLowerCase();
      final snapshot = await FirebaseFirestore.instance
          .collection('guardians')
          .where('guardian_email', isEqualTo: normalizedEmail)
          .where('relationship_status', isEqualTo: 'active')
          .get();
      
      _linkedUserIds = snapshot.docs
          .map((doc) => doc.data()['user_id'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toList();
      
      setState(() => _isLoadingUsers = false);
    } catch (e) {
      print('Error loading linked users: $e');
      setState(() => _isLoadingUsers = false);
    }
  }

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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Message', style: titleStyle),
        content: Text(
          'Are you sure you want to delete this message?',
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
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _databaseService.deleteMessageAsGuardian(messageId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting message: $e')),
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
          'Are you sure you want to delete all SMS alerts? This action cannot be undone.',
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
      final deletedCount = await _databaseService.deleteAllMessagesAsGuardian();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted $deletedCount message${deletedCount != 1 ? 's' : ''}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting messages: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Message Inbox'),
            Text(
              'SMS Alerts from Users',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _deleteAllMessages,
            tooltip: 'Delete All',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _databaseService.getGuardianMessagesStream(),
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
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SMS alerts from users will appear here',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Filter messages to only show those from linked users
          final allMessages = snapshot.data!.docs;
          final messages = allMessages.where((doc) {
            if (_isLoadingUsers) return false; // Wait for user IDs to load
            final data = doc.data() as Map<String, dynamic>;
            final userId = data['user_id'] as String? ?? '';
            return _linkedUserIds.contains(userId);
          }).toList();
          
          if (_isLoadingUsers) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (messages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SMS alerts from users will appear here',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final doc = messages[index];
              final data = doc.data() as Map<String, dynamic>;
              final messageId = doc.id;
              final content = data['content'] as String? ?? 'No content';
              final messageType = data['message_type'] as String? ?? 'text';
              // Handle both bool and int (0/1) for is_read
              final isReadValue = data['is_read'];
              final isRead = isReadValue is bool 
                  ? isReadValue 
                  : (isReadValue is int ? isReadValue != 0 : false);
              final createdAt = data['created_at'];
              
              // Get user name from userId (we'll show it if available)
              String userName = 'User';
              
              // Mark as read when displayed
              if (!isRead) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _markAsRead(messageId);
                });
              }

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                elevation: isRead ? 1 : 3,
                color: isRead ? null : Colors.orange.shade50,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: messageType == 'alert' 
                        ? AppTheme.error 
                        : (isRead ? Colors.grey : AppTheme.info),
                    child: Icon(
                      messageType == 'alert' 
                          ? Icons.warning 
                          : (messageType == 'voice' ? Icons.mic : Icons.message),
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    messageType == 'alert' 
                        ? 'SMS Alert from $userName' 
                        : 'Message from $userName',
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
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: Colors.red,
                        onPressed: () => _deleteMessage(messageId),
                        tooltip: 'Delete',
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
    );
  }
}

