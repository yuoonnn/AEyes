import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'database_service.dart';

/// SMS service for sending alerts to guardians
class SMSService {
  final DatabaseService _databaseService = DatabaseService();
  
  // Default predefined messages
  static const List<String> _defaultMessages = [
    'Please call me',
    'I need help',
    'I am lost',
    'Emergency - please come',
    'I am safe',
  ];
  
  /// Get predefined messages from storage
  Future<List<String>> getPredefinedMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = prefs.getString('predefined_sms_messages');
      
      if (messagesJson != null) {
        final List<dynamic> messages = json.decode(messagesJson);
        return messages.cast<String>();
      }
    } catch (e) {
      print('Error loading predefined messages: $e');
    }
    
    // Return default messages if none saved
    return List<String>.from(_defaultMessages);
  }
  
  /// Save predefined messages to storage
  Future<void> savePredefinedMessages(List<String> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = json.encode(messages);
      await prefs.setString('predefined_sms_messages', messagesJson);
      print('✅ Predefined messages saved');
    } catch (e) {
      print('Error saving predefined messages: $e');
      rethrow;
    }
  }
  
  /// Get guardians with phone numbers
  Future<List<Map<String, dynamic>>> getGuardiansWithPhones() async {
    try {
      final guardians = await _databaseService.getGuardians();
      return guardians.where((guardian) {
        final phone = guardian['phone'] as String?;
        return phone != null && phone.isNotEmpty;
      }).toList();
    } catch (e) {
      print('Error getting guardians: $e');
      return [];
    }
  }
  
  /// Send SMS to a guardian using the device's SMS app
  Future<bool> sendSMS({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      // Format phone number (remove spaces, dashes, etc.)
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      
      // Create SMS URL
      final uri = Uri.parse('sms:$cleanPhone?body=${Uri.encodeComponent(message)}');
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      } else {
        print('Cannot launch SMS URL');
        return false;
      }
    } catch (e) {
      print('Error sending SMS: $e');
      return false;
    }
  }
  
  /// Send SMS to all guardians with a predefined message
  /// Also saves the alert to Firestore so guardians can see it in their inbox
  Future<Map<String, bool>> sendSMSToAllGuardians(String message) async {
    final results = <String, bool>{};
    
    try {
      final guardians = await getGuardiansWithPhones();
      
      if (guardians.isEmpty) {
        print('No guardians with phone numbers found');
        return results;
      }
      
      // Send SMS to each guardian and save to Firestore
      for (final guardian in guardians) {
        final phone = guardian['phone'] as String?;
        final name = guardian['guardian_name'] as String? ?? 'Guardian';
        final guardianId = guardian['guardian_id'] as String?;
        
        if (phone != null && phone.isNotEmpty) {
          final success = await sendSMS(
            phoneNumber: phone,
            message: message,
          );
          results[name] = success;
          
          // Save SMS alert to Firestore so guardian can see it in inbox
          if (success && guardianId != null) {
            try {
              // Get current user ID for the message
              final currentUserId = _databaseService.currentUserId;
              if (currentUserId != null) {
                await _databaseService.sendMessage(
                  guardianId: guardianId,
                  messageType: 'alert', // Mark as alert type
                  content: 'SMS Alert: $message',
                  direction: 'user_to_guardian',
                );
                print('✅ SMS alert saved to Firestore for $name');
              } else {
                print('⚠️ Cannot save SMS alert - user not authenticated');
              }
            } catch (e) {
              print('⚠️ Failed to save SMS alert to Firestore: $e');
              // Continue even if Firestore save fails
            }
          }
          
          if (success) {
            print('✅ SMS sent to $name ($phone)');
          } else {
            print('❌ Failed to send SMS to $name ($phone)');
          }
        }
      }
    } catch (e) {
      print('Error sending SMS to all guardians: $e');
    }
    
    return results;
  }
  
  /// Send SMS to a specific guardian
  Future<bool> sendSMSToGuardian({
    required String guardianId,
    required String message,
  }) async {
    try {
      final guardians = await _databaseService.getGuardians();
      final guardian = guardians.firstWhere(
        (g) => g['guardian_id'] == guardianId,
        orElse: () => <String, dynamic>{},
      );
      
      if (guardian.isEmpty) {
        print('Guardian not found');
        return false;
      }
      
      final phone = guardian['phone'] as String?;
      if (phone == null || phone.isEmpty) {
        print('Guardian has no phone number');
        return false;
      }
      
      return await sendSMS(phoneNumber: phone, message: message);
    } catch (e) {
      print('Error sending SMS to guardian: $e');
      return false;
    }
  }
}

