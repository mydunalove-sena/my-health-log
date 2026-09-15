import '../models/lab_capture_candidate.dart';
import '../models/weight_capture_candidate.dart';
import 'inbody_weight_ocr_parser.dart';

class WeightCaptureParserService {
  const WeightCaptureParserService({
    InBodyWeightOcrParser inBodyParser = const InBodyWeightOcrParser(),
  }) : this._(inBodyParser);

  const WeightCaptureParserService._(this._inBodyParser);

  final InBodyWeightOcrParser _inBodyParser;

  WeightCaptureCandidate? parse(List<LabOcrDocument> documents) {
    if (!_hasWeightLabel(documents)) {
      return null;
    }
    return _inBodyParser.parse(documents);
  }

  bool _hasWeightLabel(List<LabOcrDocument> documents) {
    for (final document in documents) {
      for (final line in document.lines) {
        final text = line.text.replaceAll(RegExp(r'\s+'), '').toLowerCase();
        if (text.contains('weight') || text.contains('\uCCB4\uC911')) {
          return true;
        }
      }
    }
    return false;
  }
}
