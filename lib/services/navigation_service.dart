import 'package:flutter/foundation.dart';

class NavigationService {
  // Singleton
  static final NavigationService instance = NavigationService._internal();

  factory NavigationService() {
    return instance;
  }

  NavigationService._internal();

  // State
  final ValueNotifier<bool> isNavigating = ValueNotifier<bool>(false);

  void startNavigation() {
    isNavigating.value = true;
  }

  void stopNavigation() {
    isNavigating.value = false;
  }
}
