import 'dart:async';

/// Tracks latency for the capture → analysis → TTS pipeline.
class LatencyMetricsService {
  LatencyMetricsService._internal();
  static final LatencyMetricsService instance =
      LatencyMetricsService._internal();

  final List<LatencySample> _history = <LatencySample>[];
  final StreamController<List<LatencySample>> _historyController =
      StreamController<List<LatencySample>>.broadcast();

  _LatencyMeasurement? _active;

  /// Stream of latency samples (most recent first).
  Stream<List<LatencySample>> get historyStream =>
      _historyController.stream;

  /// Current cached history (most recent first).
  List<LatencySample> get history => List.unmodifiable(_history);

  /// Start a new capture cycle measurement.
  void startCycle({required String triggerLabel}) {
    // If a measurement is already running, mark it aborted to avoid stale data.
    if (_active != null) {
      _finalizeActive(abortedReason: 'superseded by $triggerLabel');
    }
    _active = _LatencyMeasurement(
      triggerLabel: triggerLabel,
      startedAt: DateTime.now(),
    );
  }

  /// Note when image bytes arrive from ESP32.
  void markImageReceived({int? byteLength}) {
    final measurement = _active;
    if (measurement == null) return;
    measurement.imageReceivedAt = DateTime.now();
    if (byteLength != null) {
      measurement.metadata['imageBytes'] = byteLength.toString();
    }
  }

  /// Note when OpenAI finishes analysis.
  void markAnalysisComplete() {
    final measurement = _active;
    if (measurement == null) return;
    measurement.analysisCompletedAt = DateTime.now();
  }

  /// Mark the cycle complete once TTS output begins.
  void markTtsStarted({String? ttsPreview}) {
    final measurement = _active;
    if (measurement == null) return;
    measurement.ttsStartedAt = DateTime.now();
    if (ttsPreview != null && ttsPreview.isNotEmpty) {
      final maxLength = ttsPreview.length > 80 ? 80 : ttsPreview.length;
      measurement.metadata['ttsPreview'] = ttsPreview.substring(0, maxLength);
    }
    _finalizeActive();
  }

  /// Cancel the current measurement if an unrecoverable error occurs.
  void cancelActive(String reason) {
    _finalizeActive(abortedReason: reason);
  }

  void _finalizeActive({String? abortedReason}) {
    final measurement = _active;
    if (measurement == null) return;
    final sample = measurement.toSample(abortedReason: abortedReason);
    _active = null;
    _history.insert(0, sample);
    if (_history.length > 25) {
      _history.removeRange(25, _history.length);
    }
    _historyController.add(List.unmodifiable(_history));
  }
}

class LatencySample {
  LatencySample({
    required this.triggerLabel,
    required this.startedAt,
    this.imageReceivedAt,
    this.analysisCompletedAt,
    this.ttsStartedAt,
    this.status = LatencyStatus.completed,
    this.metadata = const {},
  });

  final String triggerLabel;
  final DateTime startedAt;
  final DateTime? imageReceivedAt;
  final DateTime? analysisCompletedAt;
  final DateTime? ttsStartedAt;
  final LatencyStatus status;
  final Map<String, String> metadata;

  Duration? get buttonToImage =>
      _diff(startedAt, imageReceivedAt);

  Duration? get imageToAnalysis =>
      _diff(imageReceivedAt, analysisCompletedAt);

  Duration? get analysisToTts =>
      _diff(analysisCompletedAt, ttsStartedAt);

  Duration? get total =>
      _diff(startedAt, ttsStartedAt);

  String get statusLabel => switch (status) {
        LatencyStatus.completed => 'Completed',
        LatencyStatus.aborted => 'Aborted',
      };

  static Duration? _diff(DateTime? start, DateTime? end) {
    if (start == null || end == null) return null;
    return end.difference(start);
  }
}

enum LatencyStatus { completed, aborted }

class _LatencyMeasurement {
  _LatencyMeasurement({
    required this.triggerLabel,
    required this.startedAt,
  });

  final String triggerLabel;
  final DateTime startedAt;
  final Map<String, String> metadata = <String, String>{};

  DateTime? imageReceivedAt;
  DateTime? analysisCompletedAt;
  DateTime? ttsStartedAt;

  LatencySample toSample({String? abortedReason}) {
    return LatencySample(
      triggerLabel: triggerLabel,
      startedAt: startedAt,
      imageReceivedAt: imageReceivedAt,
      analysisCompletedAt: analysisCompletedAt,
      ttsStartedAt: ttsStartedAt,
      status: abortedReason == null
          ? LatencyStatus.completed
          : LatencyStatus.aborted,
      metadata: {
        ...metadata,
        if (abortedReason != null) 'aborted': abortedReason,
      }..removeWhere((key, value) => value.isEmpty),
    );
  }
}

