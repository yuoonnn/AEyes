import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

/// In-app alert service for notifying guardians
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
  
  /// Send emergency alert to all guardians via in-app messaging
  /// Returns a map with guardian names and their status
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
      
      final userProfile = await _databaseService.getUserProfile();
      final userName = (userProfile?.name?.trim().isNotEmpty ?? false)
          ? userProfile!.name
          : 'your loved one';
      
      // Process each guardian
      for (final guardian in allGuardians) {
        final name = guardian['guardian_name'] as String? ?? 'Guardian';
        final guardianId = guardian['guardian_id'] as String?;
        
        // Save alert to Firestore so guardian can see it in the app
        if (guardianId != null) {
          try {
            await _databaseService.sendMessage(
              guardianId: guardianId,
              messageType: 'alert', // Mark as alert type
              content: 'Emergency alert from $userName: $message',
              direction: 'user_to_guardian',
            );
            print('✅ Alert saved to guardian app for $name');
            
            // Update result status
            results[name] = 'app_alert';
          } catch (e) {
            print('⚠️ Failed to save alert to Firestore for $name: $e');
            results[name] = 'failed';
          }
        }
      }
      
      // Attempt to log emergency alert for auditing (best effort)
      try {
        await _databaseService.createEmergencyAlert(
          alertType: 'manual',
          severity: 'critical',
        );
      } catch (e) {
        print('⚠️ Failed to log emergency alert: $e');
      }
      
      // Store summary in results for easy access
      final alertCount = results.values.where((v) => v == 'app_alert').length;
      results['_summary'] = 'app:$alertCount';
      
    } catch (e) {
      print('Error sending SMS to all guardians: $e');
    }
    
    return results;
  }
}

