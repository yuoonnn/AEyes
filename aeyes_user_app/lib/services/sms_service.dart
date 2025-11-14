import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'database_service.dart';

/// SMS service for sending alerts to guardians
class SMSService {
  final DatabaseService _databaseService = DatabaseService();
  
  // Default predefined message
  static const String _defaultMessage = 'I need help - please call me';
  
  /// Get single predefined message from storage
  Future<String> getPredefinedMessage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final message = prefs.getString('predefined_sms_message');
      
      if (message != null && message.isNotEmpty) {
        return message;
      }
    } catch (e) {
      print('Error loading predefined message: $e');
    }
    
    // Return default message if none saved
    return _defaultMessage;
  }
  
  /// Save single predefined message to storage
  Future<void> savePredefinedMessage(String message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('predefined_sms_message', message.trim());
      print('✅ Predefined message saved');
    } catch (e) {
      print('Error saving predefined message: $e');
      rethrow;
    }
  }
  
  // Keep old methods for backward compatibility (deprecated)
  @Deprecated('Use getPredefinedMessage() instead')
  Future<List<String>> getPredefinedMessages() async {
    final message = await getPredefinedMessage();
    return [message];
  }
  
  @Deprecated('Use savePredefinedMessage() instead')
  Future<void> savePredefinedMessages(List<String> messages) async {
    if (messages.isNotEmpty) {
      await savePredefinedMessage(messages.first);
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
  /// Returns a map with guardian names and their status: 'sms_success', 'sms_failed', 'app_only', 'both'
  Future<Map<String, String>> sendSMSToAllGuardians(String message) async {
    final results = <String, String>{};
    
    try {
      // Get ALL guardians (not just those with phone numbers)
      final allGuardians = await _databaseService.getGuardians();
      
      if (allGuardians.isEmpty) {
        print('No guardians linked to this user');
        return results;
      }
      
      // Get current user ID for the message
      final currentUserId = _databaseService.currentUserId;
      if (currentUserId == null) {
        print('⚠️ Cannot send messages - user not authenticated');
        return results;
      }
      
      int appMessageCount = 0;
      int smsSuccessCount = 0;
      int smsFailedCount = 0;
      
      // Process each guardian
      for (final guardian in allGuardians) {
        final phone = guardian['phone'] as String?;
        final name = guardian['guardian_name'] as String? ?? 'Guardian';
        final guardianId = guardian['guardian_id'] as String?;
        
        bool smsSent = false;
        bool appMessageSent = false;
        
        // Send SMS if phone number exists
        if (phone != null && phone.isNotEmpty) {
          try {
            final success = await sendSMS(
              phoneNumber: phone,
              message: message,
            );
            smsSent = success;
            if (success) {
              smsSuccessCount++;
              results[name] = 'sms_success';
            } else {
              smsFailedCount++;
              results[name] = 'sms_failed';
            }
          } catch (e) {
            print('Error sending SMS to $name: $e');
            smsFailedCount++;
            results[name] = 'sms_failed';
          }
        }
        
        // Always save to Firestore (guardian app) regardless of SMS status
        if (guardianId != null) {
          try {
            await _databaseService.sendMessage(
              guardianId: guardianId,
              messageType: 'alert', // Mark as alert type
              content: 'Emergency Alert: $message',
              direction: 'user_to_guardian',
            );
            appMessageSent = true;
            appMessageCount++;
            print('✅ Alert saved to guardian app for $name');
            
            // Update result status
            if (smsSent) {
              results[name] = 'both'; // Both SMS and app message sent
            } else if (phone != null && phone.isNotEmpty) {
              results[name] = 'app_only'; // App message sent, SMS failed
            } else {
              results[name] = 'app_only'; // App message sent, no phone number
            }
          } catch (e) {
            print('⚠️ Failed to save alert to Firestore for $name: $e');
            // If SMS was sent but app message failed, keep SMS status
            if (!smsSent && results[name] == null) {
              results[name] = 'failed';
            }
          }
        }
      }
      
      // Store summary in results for easy access
      results['_summary'] = 'sms:$smsSuccessCount|failed:$smsFailedCount|app:$appMessageCount';
      
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

