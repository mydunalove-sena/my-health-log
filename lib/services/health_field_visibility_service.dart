import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum HealthFieldVisibilityKey {
  weight,
  bloodPressure,
  waterIntake,
  steps,
  sleepHours,
  condition,
}

class HealthFieldVisibilityService extends ChangeNotifier {
  HealthFieldVisibilityService([this._preferences]) : _persistent = true;

  HealthFieldVisibilityService.inMemory() : _persistent = false;

  static const _prefix = 'health_field_visibility.';

  final bool _persistent;
  SharedPreferences? _preferences;
  final Map<HealthFieldVisibilityKey, bool> _visible = {
    for (final field in HealthFieldVisibilityKey.values) field: true,
  };

  bool isVisible(HealthFieldVisibilityKey field) {
    return _visible[field] ?? true;
  }

  bool get weightVisible => isVisible(HealthFieldVisibilityKey.weight);
  bool get bloodPressureVisible =>
      isVisible(HealthFieldVisibilityKey.bloodPressure);
  bool get waterIntakeVisible =>
      isVisible(HealthFieldVisibilityKey.waterIntake);
  bool get stepsVisible => isVisible(HealthFieldVisibilityKey.steps);
  bool get sleepHoursVisible => isVisible(HealthFieldVisibilityKey.sleepHours);
  bool get conditionVisible => isVisible(HealthFieldVisibilityKey.condition);

  Future<void> load() async {
    if (!_persistent) {
      notifyListeners();
      return;
    }
    _preferences ??= await SharedPreferences.getInstance();
    for (final field in HealthFieldVisibilityKey.values) {
      _visible[field] = _preferences!.getBool(_storageKey(field)) ?? true;
    }
    notifyListeners();
  }

  Future<void> setVisible(HealthFieldVisibilityKey field, bool visible) async {
    if (_visible[field] == visible) {
      return;
    }
    _visible[field] = visible;
    if (_persistent) {
      _preferences ??= await SharedPreferences.getInstance();
      await _preferences!.setBool(_storageKey(field), visible);
    }
    notifyListeners();
  }

  String _storageKey(HealthFieldVisibilityKey field) {
    return '$_prefix${field.name}';
  }
}
