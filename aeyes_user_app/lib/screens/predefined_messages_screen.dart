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
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessage();
  }

  Future<void> _loadMessage() async {
    setState(() => _isLoading = true);
    try {
      final message = await _smsService.getPredefinedMessage();
      setState(() {
        _messageController.text = message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading message: $e')),
        );
      }
    }
  }

  Future<void> _saveMessage() async {
    try {
      final message = _messageController.text.trim();
      
      if (message.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message cannot be empty'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
        return;
      }
      
      await _smsService.savePredefinedMessage(message);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message saved successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate changes were made
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving message: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SMS Message'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveMessage,
            tooltip: 'Save Message',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: AppTheme.paddingLG,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Instructions
                  Container(
                    padding: AppTheme.paddingMD,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryWithOpacity(0.1),
                      borderRadius: AppTheme.borderRadiusMD,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.primaryGreen),
                        SizedBox(width: AppTheme.spacingMD),
                        Expanded(
                          child: Text(
                            'This message will be automatically sent to all your guardians when you press Button 1. Make it clear and concise.',
                            style: AppTheme.textStyleBody,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingXL),
                  
                  // Message input
                  Text(
                    'Emergency Message',
                    style: AppTheme.textStyleTitle.copyWith(
                      fontWeight: AppTheme.fontWeightBold,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingSM),
                  TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'e.g., "I need help - please call me"',
                      border: OutlineInputBorder(
                        borderRadius: AppTheme.borderRadiusMD,
                      ),
                      helperText: 'This message will be sent via SMS and appear in guardian app',
                    ),
                    maxLines: 4,
                    maxLength: 160, // SMS character limit
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(160),
                    ],
                  ),
                  SizedBox(height: AppTheme.spacingXL),
                  
                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveMessage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: AppTheme.paddingMD,
                      ),
                      child: const Text('Save Message'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
