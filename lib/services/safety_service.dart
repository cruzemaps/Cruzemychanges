import 'package:flutter/foundation.dart';
import 'package:cruze_mobile/services/user_service.dart';

class SafetyEvent {
  final String title;
  final String description;
  final DateTime timestamp;
  final double penalty;

  SafetyEvent({
    required this.title,
    required this.description,
    required this.timestamp,
    required this.penalty,
  });
}

class SafetyService {
  // Singleton
  static final SafetyService instance = SafetyService._internal();

  factory SafetyService() {
    return instance;
  }

  SafetyService._internal() {
    // Initialize from UserService (Source of Truth)
    _totalDistanceMiles = UserService.instance.totalMiles.value;
    double currentScore = UserService.instance.safetyScore.value.toDouble();
    
    // Reverse engineer penalty: Penalty = (100 - Score) * Miles
    if (_totalDistanceMiles > 0) {
      _accumulatedPenalty = (100 - currentScore) * _totalDistanceMiles;
    }
  }

  // State
  final ValueNotifier<double> safetyScore = ValueNotifier<double>(100.0);
  final ValueNotifier<List<SafetyEvent>> events = ValueNotifier<List<SafetyEvent>>([]);

  // Internal Logic
  double _accumulatedPenalty = 0.0;
  double _totalDistanceMiles = 0.0;
  
  // Getters
  double get totalDistanceMiles => _totalDistanceMiles;
  double get accumulatedPenalty => _accumulatedPenalty;

  void updateDistance(double milesDelta) {
    if (milesDelta <= 0) return;
    
    _totalDistanceMiles += milesDelta;
    _recalculateScore();
  }

  void recordEvent(String title, String description, double penalty) {
    _accumulatedPenalty += penalty;
    
    // Add to history
    final newEvent = SafetyEvent(
      title: title,
      description: description,
      timestamp: DateTime.now(),
      penalty: penalty,
    );
    
    final currentList = List<SafetyEvent>.from(events.value);
    currentList.insert(0, newEvent); // Newest first
    events.value = currentList;

    _recalculateScore();
  }

  void _recalculateScore() {
    // Avoid division by zero, start with small buffer
    double miles = _totalDistanceMiles < 0.1 ? 0.1 : _totalDistanceMiles;
    
    double calculatedScore = 100 - (_accumulatedPenalty / miles);

    if (calculatedScore < 0) calculatedScore = 0;
    if (calculatedScore > 100) calculatedScore = 100;

    safetyScore.value = calculatedScore;
    
    // Sync back to UserService
    UserService.instance.updateStats(calculatedScore.round(), _totalDistanceMiles);
  }

  void clearEvents() {
    events.value = [];
  }
}
