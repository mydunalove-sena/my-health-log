import '../models/lab_capture_candidate.dart';
import '../models/weight_capture_candidate.dart';
import 'lab_ocr_service.dart';
import 'weight_capture_parser_service.dart';

enum WeightCaptureProductionBranch { inBody, manualReview }

class WeightCaptureProductionResult {
  const WeightCaptureProductionResult({
    required this.documents,
    required this.candidate,
    required this.branch,
    required this.firstOcrCallCount,
    required this.totalElapsedMs,
  });

  final List<LabOcrDocument> documents;
  final WeightCaptureCandidate? candidate;
  final WeightCaptureProductionBranch branch;
  final int firstOcrCallCount;
  final int totalElapsedMs;
}

class WeightCaptureOrchestrator {
  const WeightCaptureOrchestrator({
    this.parserService = const WeightCaptureParserService(),
  });

  final WeightCaptureParserService parserService;

  Future<WeightCaptureProductionResult> capture({
    required String imagePath,
    required LabOcrService ocrService,
  }) async {
    final timer = Stopwatch()..start();
    final documents = await ocrService.recognize([imagePath]);
    final candidate = parserService.parse(documents);
    timer.stop();

    return WeightCaptureProductionResult(
      documents: documents,
      candidate: candidate,
      branch: candidate == null
          ? WeightCaptureProductionBranch.manualReview
          : WeightCaptureProductionBranch.inBody,
      firstOcrCallCount: 1,
      totalElapsedMs: timer.elapsedMilliseconds,
    );
  }
}
