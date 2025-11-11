import 'package:flutter/foundation.dart';

class AIState extends ChangeNotifier {
  String? _lastAnalysis;
  DateTime? _lastUpdatedAt;
  final List<Map<String, dynamic>> _history = [];
  final int _maxHistory = 20;

  String? get lastAnalysis => _lastAnalysis;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  List<Map<String, dynamic>> get history => List.unmodifiable(_history);

  void setAnalysis(String text) {
    _lastAnalysis = text;
    _lastUpdatedAt = DateTime.now();
    _history.insert(0, {
      'text': text,
      'at': _lastUpdatedAt,
    });
    if (_history.length > _maxHistory) {
      _history.removeRange(_maxHistory, _history.length);
    }
    notifyListeners();
  }
}


