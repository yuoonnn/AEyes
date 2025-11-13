import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/sms_service.dart';
import '../theme/app_theme.dart';

class PredefinedMessagesScreen extends StatefulWidget {
  const PredefinedMessagesScreen({Key? key}) : super(key: key);

  @override
  State<PredefinedMessagesScreen> createState() => _PredefinedMessagesScreenState();
}

class _PredefinedMessagesScreenState extends State<PredefinedMessagesScreen> {
  final SMSService _smsService = SMSService();
  List<String> _messages = [];
  bool _isLoading = true;
  final Map<int, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final messages = await _smsService.getPredefinedMessages();
      setState(() {
        _messages = messages;
        // Initialize controllers for each message
        for (int i = 0; i < _messages.length; i++) {
          _controllers[i] = TextEditingController(text: _messages[i]);
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading messages: $e')),
        );
      }
    }
  }

  Future<void> _saveMessages() async {
    try {
      // Update messages from controllers
      final updatedMessages = <String>[];
      for (int i = 0; i < _controllers.length; i++) {
        final text = _controllers[i]?.text.trim() ?? '';
        if (text.isNotEmpty) {
          updatedMessages.add(text);
        }
      }
      
      await _smsService.savePredefinedMessages(updatedMessages);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Messages saved successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate changes were made
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving messages: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _addNewMessage() {
    setState(() {
      final newIndex = _messages.length;
      _messages.add('');
      _controllers[newIndex] = TextEditingController();
    });
  }

  void _removeMessage(int index) {
    setState(() {
      _controllers[index]?.dispose();
      _controllers.remove(index);
      _messages.removeAt(index);
      
      // Rebuild controllers map with new indices
      final newControllers = <int, TextEditingController>{};
      final newMessages = <String>[];
      int newIndex = 0;
      
      for (int i = 0; i < _messages.length; i++) {
        if (i != index) {
          final controller = _controllers[i];
          if (controller != null) {
            newControllers[newIndex] = controller;
            newMessages.add(_messages[i]);
            newIndex++;
          }
        }
      }
      
      _controllers.clear();
      _controllers.addAll(newControllers);
      _messages = newMessages;
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Predefined SMS Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveMessages,
            tooltip: 'Save Messages',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Instructions
                Container(
                  padding: AppTheme.paddingMD,
                  color: AppTheme.primaryWithOpacity(0.1),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.primaryGreen),
                      SizedBox(width: AppTheme.spacingMD),
                      Expanded(
                        child: Text(
                          'Edit your predefined messages for SMS alerts. These will be available when Button 1 is pressed.',
                          style: AppTheme.textStyleBody,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Messages list
                Expanded(
                  child: ListView.builder(
                    padding: AppTheme.paddingMD,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: EdgeInsets.only(bottom: AppTheme.spacingMD),
                        elevation: AppTheme.elevationMedium,
                        child: Padding(
                          padding: AppTheme.paddingMD,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controllers[index],
                                  decoration: InputDecoration(
                                    labelText: 'Message ${index + 1}',
                                    hintText: 'Enter message text',
                                    border: OutlineInputBorder(
                                      borderRadius: AppTheme.borderRadiusMD,
                                    ),
                                  ),
                                  maxLines: 2,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(160), // SMS character limit
                                  ],
                                ),
                              ),
                              SizedBox(width: AppTheme.spacingSM),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                                onPressed: _messages.length > 1
                                    ? () => _removeMessage(index)
                                    : null,
                                tooltip: 'Remove Message',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // Add button
                Padding(
                  padding: AppTheme.paddingMD,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add New Message'),
                    onPressed: _addNewMessage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: AppTheme.paddingMD,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

