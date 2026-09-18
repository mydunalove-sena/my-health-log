import '../models/lab_capture_candidate.dart';
import '../models/lab_result.dart';
import '../models/lab_test_definition.dart';

class LabCaptureMappingService {
  LabCaptureMappingService(this.definitions);

  final List<LabTestDefinition> definitions;

  static const explicitAliases = <String, String>{
    'calcium(칼슘)': 'calcium',
    'p(인)': 'phosphorus',
    'inorganic p(인)': 'phosphorus',
    'glucose(혈당)': 'glucose',
    'bun(혈액요소질소)': 'bun',
    'creatinine(크레아티닌)': 'creatinine',
    'uric acid(요산)': 'uric_acid',
    'total cholesterol(총콜레스테롤)': 'total_cholesterol',
    'total cholesterol': 'total_cholesterol',
    'hdl-cholesterol': 'hdl',
    'albumin(알부민)': 'albumin',
    'total protein(e)': 'total_protein',
    'total protein(총 단백)': 'total_protein',
    'total protein(총단백)': 'total_protein',
    'alk. phos(알칼리인산분해효소)': 'alp',
    'alk. phos': 'alp',
    'ast(got)(아스파르테이트아미노전이효소)': 'ast',
    'ast(got)': 'ast',
  };

  List<LabCaptureCandidate> map(
    List<ParsedLabCaptureCandidate> parsed, {
    DateTime? date,
    List<LabResult> existingResults = const [],
    String idPrefix = '',
  }) {
    final candidates = <LabCaptureCandidate>[];
    var nextId = 0;
    for (final item in parsed) {
      final definition = _matchDefinition(item.rawTestName);
      final key = _candidateKey(item, definition);
      final duplicateIndex = candidates.indexWhere(
        (candidate) =>
            _candidateKeyForCandidate(candidate) == key &&
            candidate.value == item.value &&
            _unitsAreCompatible(candidate.ocrUnit, item.unit),
      );
      if (duplicateIndex != -1) {
        final duplicate = candidates[duplicateIndex];
        if (_isBlankUnit(duplicate.ocrUnit) && !_isBlankUnit(item.unit)) {
          duplicate.ocrUnit = item.unit;
        }
        final indices = duplicate.sourceImageIndices;
        if (!indices.contains(item.sourceImageIndex)) {
          indices.add(item.sourceImageIndex);
        }
        continue;
      }

      final conflictIndex = candidates.indexWhere(
        (candidate) => _candidateKeyForCandidate(candidate) == key,
      );
      final hasConflict = conflictIndex != -1;
      if (hasConflict) {
        candidates[conflictIndex].hasImportConflict = true;
        candidates[conflictIndex].isSelected = false;
      }

      final candidate = LabCaptureCandidate(
        id: '$idPrefix${nextId++}',
        rawTestName: item.rawTestName,
        value: item.value,
        ocrUnit: item.unit,
        sourceImageIndices: [item.sourceImageIndex],
        mappingStatus: definition == null
            ? LabCaptureMappingStatus.unmapped
            : LabCaptureMappingStatus.mapped,
        definition: definition,
        date: item.date ?? date,
        hasImportConflict: hasConflict,
        existingResult: _existingFor(definition, existingResults),
      );
      if (candidate.hasExistingSameValue) {
        candidate.isSelected = false;
      }
      candidates.add(candidate);
    }
    return candidates;
  }

  LabTestDefinition? matchDefinition(String ocrName) =>
      _matchDefinition(ocrName);

  String canonicalKeyForName(String name) => _canonicalKeyForName(name);

  LabResult? existingForCandidate(
    LabCaptureCandidate candidate,
    List<LabResult> existingResults,
  ) {
    if (!candidate.isMapped) return null;
    final key = _candidateKeyForCandidate(candidate);
    for (final result in existingResults) {
      if (_canonicalKeyForName(result.testName) == key) {
        return result;
      }
    }
    return null;
  }

  LabTestDefinition? _matchDefinition(String ocrName) {
    final variants = _comparisonVariants(ocrName);
    final definitionsById = {
      for (final definition in definitions) definition.id: definition,
    };
    final matchedIds = <String>{};
    for (final definition in definitions) {
      if (_comparisonVariants(definition.displayName).any(variants.contains)) {
        matchedIds.add(definition.id);
      }
    }
    for (final alias in explicitAliases.entries) {
      if (definitionsById.containsKey(alias.value) &&
          _comparisonVariants(alias.key).any(variants.contains)) {
        matchedIds.add(alias.value);
      }
    }
    // Exact names, aliases and annotation variants have equal authority.
    // Never resolve a collision by registry order, including custom names.
    return matchedIds.length == 1 ? definitionsById[matchedIds.single] : null;
  }

  LabResult? _existingFor(
    LabTestDefinition? definition,
    List<LabResult> existingResults,
  ) {
    if (definition == null) return null;
    final key = _canonicalKeyForDefinition(definition);
    for (final result in existingResults) {
      if (_canonicalKeyForName(result.testName) == key) {
        return result;
      }
    }
    return null;
  }

  String _candidateKey(
    ParsedLabCaptureCandidate item,
    LabTestDefinition? definition,
  ) {
    return definition == null
        ? 'raw:${_normalizeName(item.rawTestName)}'
        : _canonicalKeyForDefinition(definition);
  }

  String _candidateKeyForCandidate(LabCaptureCandidate candidate) {
    return candidate.definition == null
        ? 'raw:${_normalizeName(candidate.rawTestName)}'
        : _canonicalKeyForDefinition(candidate.definition!);
  }

  String _canonicalKeyForDefinition(LabTestDefinition definition) {
    return 'def:${definition.id}';
  }

  String _canonicalKeyForName(String name) {
    final definition = _matchDefinition(name);
    return definition == null
        ? 'raw:${_normalizeName(name)}'
        : _canonicalKeyForDefinition(definition);
  }

  static String _normalizeName(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s*\(\s*'), '(')
        .replaceAll(RegExp(r'\s+\)'), ')')
        .trim()
        .toLowerCase();
  }

  static Set<String> _comparisonVariants(String value) {
    final normalized = _normalizeName(value);
    final variants = <String>{if (normalized.isNotEmpty) normalized};
    if (!normalized.endsWith(')')) return variants;

    var depth = 0;
    var trailingStart = -1;
    for (var index = 0; index < normalized.length; index++) {
      if (normalized[index] == '(') {
        if (depth == 0) trailingStart = index;
        depth++;
      } else if (normalized[index] == ')') {
        depth--;
        if (depth < 0) return variants;
      }
    }
    if (depth != 0 || trailingStart <= 0) return variants;
    final annotation = normalized.substring(
      trailingStart + 1,
      normalized.length - 1,
    );
    // Only a flat, balanced, trailing Hangul annotation supplies a base variant.
    // Meaningful qualifiers such as (GOT)/(E), hyphens and slashes stay intact.
    if (annotation.contains('(') ||
        annotation.contains(')') ||
        !RegExp(r'[가-힣ㄱ-ㅣᄀ-ᇿ]').hasMatch(annotation)) {
      return variants;
    }
    final base = normalized.substring(0, trailingStart).trim();
    if (base.isNotEmpty) variants.add(base);
    return variants;
  }

  static bool _unitsAreCompatible(String? left, String? right) {
    final normalizedLeft = _normalizeUnit(left);
    final normalizedRight = _normalizeUnit(right);
    return normalizedLeft.isEmpty ||
        normalizedRight.isEmpty ||
        normalizedLeft == normalizedRight;
  }

  static bool _isBlankUnit(String? value) => _normalizeUnit(value).isEmpty;

  static String _normalizeUnit(String? value) {
    return (value ?? '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll(' ', '')
        .trim()
        .toLowerCase();
  }
}
