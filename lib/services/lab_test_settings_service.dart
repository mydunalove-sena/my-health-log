import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/lab_test_definitions.dart';
import '../models/lab_test_definition.dart';

class EmptyCustomLabTestNameException implements Exception {
  const EmptyCustomLabTestNameException();
}

class DuplicateLabTestDefinitionException implements Exception {
  const DuplicateLabTestDefinitionException();
}

class LabTestSettingsService extends ChangeNotifier {
  LabTestSettingsService([this._preferences]) : _persistent = true;

  LabTestSettingsService.inMemory() : _persistent = false;

  static const managementTypeKey = 'lab_settings.management_type';
  static const enabledLabTestIdsKey = 'lab_settings.enabled_lab_test_ids';
  static const customLabDefinitionsKey = 'lab_settings.custom_lab_definitions';

  final bool _persistent;
  SharedPreferences? _preferences;
  LabManagementType _managementType = LabManagementType.generalHealth;
  List<String> _enabledLabTestIds = List.of(
    defaultLabTestIdsByManagementType[LabManagementType.generalHealth]!,
  );
  final List<LabTestDefinition> _customDefinitions = [];

  LabManagementType get managementType => _managementType;
  List<String> get enabledLabTestIds => List.unmodifiable(_enabledLabTestIds);
  List<LabTestDefinition> get customDefinitions =>
      List.unmodifiable(_customDefinitions);
  List<LabTestDefinition> get allDefinitions => List.unmodifiable([
    ...predefinedLabTestDefinitions,
    ..._customDefinitions,
  ]);
  List<LabTestDefinition> get enabledDefinitions {
    final definitionsById = {for (final item in allDefinitions) item.id: item};
    return [
      for (final id in _enabledLabTestIds)
        if (definitionsById[id] != null) definitionsById[id]!,
    ];
  }

  Future<void> load() async {
    if (!_persistent) {
      notifyListeners();
      return;
    }

    _preferences ??= await SharedPreferences.getInstance();
    _managementType = LabManagementType.fromId(
      _preferences!.getString(managementTypeKey),
    );
    _customDefinitions
      ..clear()
      ..addAll(_readCustomDefinitions(_preferences!));
    _enabledLabTestIds = _readEnabledLabTestIds(_preferences!);
    notifyListeners();
  }

  Future<void> setManagementType(
    LabManagementType type, {
    bool applyPreset = true,
  }) async {
    _managementType = type;
    if (applyPreset) {
      _enabledLabTestIds = List.of(defaultLabTestIdsByManagementType[type]!);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> setEnabledLabTestIds(List<String> ids) async {
    _enabledLabTestIds = _validUniqueIds(ids);
    await _persistEnabledIds();
    notifyListeners();
  }

  Future<LabTestDefinition> addCustomDefinition({
    required String displayName,
    String? defaultUnit,
  }) async {
    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      throw const EmptyCustomLabTestNameException();
    }
    if (_hasDuplicateDisplayName(trimmedName)) {
      throw const DuplicateLabTestDefinitionException();
    }

    final trimmedUnit = defaultUnit?.trim();
    final definition = LabTestDefinition(
      id: _nextCustomId(),
      displayName: trimmedName,
      defaultUnit: trimmedUnit == null || trimmedUnit.isEmpty
          ? null
          : trimmedUnit,
    );
    _customDefinitions.add(definition);
    _enabledLabTestIds = _validUniqueIds([
      ..._enabledLabTestIds,
      definition.id,
    ]);
    await _persistCustomDefinitions();
    await _persistEnabledIds();
    notifyListeners();
    return definition;
  }

  Future<void> excludeLabTest(String id) async {
    final next = _enabledLabTestIds.where((item) => item != id).toList();
    if (next.length == _enabledLabTestIds.length) {
      return;
    }
    _enabledLabTestIds = next;
    await _persistEnabledIds();
    notifyListeners();
  }

  Future<void> _persist() async {
    if (!_persistent) {
      return;
    }
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setString(managementTypeKey, _managementType.id);
    await _persistEnabledIds();
    await _persistCustomDefinitions();
  }

  Future<void> _persistEnabledIds() async {
    if (!_persistent) {
      return;
    }
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setStringList(enabledLabTestIdsKey, _enabledLabTestIds);
  }

  Future<void> _persistCustomDefinitions() async {
    if (!_persistent) {
      return;
    }
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setString(
      customLabDefinitionsKey,
      jsonEncode(_customDefinitions.map((item) => item.toJson()).toList()),
    );
  }

  List<String> _readEnabledLabTestIds(SharedPreferences preferences) {
    final stored = preferences.getStringList(enabledLabTestIdsKey);
    if (stored == null) {
      return List.of(defaultLabTestIdsByManagementType[_managementType]!);
    }
    return _validUniqueIds(stored);
  }

  List<LabTestDefinition> _readCustomDefinitions(
    SharedPreferences preferences,
  ) {
    final text = preferences.getString(customLabDefinitionsKey);
    if (text == null || text.trim().isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is! List) {
        return [];
      }
      return [
        for (final item in decoded)
          if (item is Map)
            LabTestDefinition.fromJson(Map<String, Object?>.from(item)),
      ];
    } catch (_) {
      return [];
    }
  }

  List<String> _validUniqueIds(Iterable<String> ids) {
    final validIds = {for (final definition in allDefinitions) definition.id};
    final result = <String>[];
    for (final id in ids) {
      if (!validIds.contains(id) || result.contains(id)) {
        continue;
      }
      result.add(id);
    }
    return result;
  }

  bool _hasDuplicateDisplayName(String displayName) {
    final normalized = _normalizeName(displayName);
    return allDefinitions.any(
      (definition) => _normalizeName(definition.displayName) == normalized,
    );
  }

  String _nextCustomId() {
    final existingIds = {
      for (final definition in allDefinitions) definition.id,
    };
    var id = 'custom-${DateTime.now().microsecondsSinceEpoch}';
    while (existingIds.contains(id)) {
      id = 'custom-${DateTime.now().microsecondsSinceEpoch}';
    }
    return id;
  }

  String _normalizeName(String value) => value.trim().toLowerCase();
}
