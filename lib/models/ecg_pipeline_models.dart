class Device {
  final int id;
  final String deviceId;
  final String? label;
  final String? firmwareVersion;
  final DateTime? lastSeenAt;

  const Device({
    required this.id,
    required this.deviceId,
    this.label,
    this.firmwareVersion,
    this.lastSeenAt,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as int,
      deviceId: json['device_id'] as String,
      label: json['label'] as String?,
      firmwareVersion: json['firmware_version'] as String?,
      lastSeenAt: _date(json['last_seen_at']),
    );
  }
}

class MonitoringSession {
  final int id;
  final String sessionId;
  final String deviceId;
  final int samplingRate;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;

  const MonitoringSession({
    required this.id,
    required this.sessionId,
    required this.deviceId,
    required this.samplingRate,
    required this.status,
    required this.startedAt,
    this.endedAt,
  });

  factory MonitoringSession.fromJson(Map<String, dynamic> json) {
    return MonitoringSession(
      id: json['id'] as int,
      sessionId: json['session_id'] as String,
      deviceId: json['device_id'] as String,
      samplingRate: json['sampling_rate'] as int,
      status: json['status'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: _date(json['ended_at']),
    );
  }
}

class RawReading {
  final int id;
  final String deviceId;
  final String sessionId;
  final DateTime timestamp;
  final int samplingRate;
  final List<double> ecg;
  final List<double> ppg;
  final int? battery;
  final String status;
  final int sampleCount;

  const RawReading({
    required this.id,
    required this.deviceId,
    required this.sessionId,
    required this.timestamp,
    required this.samplingRate,
    required this.ecg,
    required this.ppg,
    required this.status,
    required this.sampleCount,
    this.battery,
  });

  factory RawReading.fromJson(Map<String, dynamic> json) {
    return RawReading(
      id: json['id'] as int,
      deviceId: json['device_id'] as String,
      sessionId: json['session_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      samplingRate: json['sampling_rate'] as int,
      ecg: _doubleList(json['ecg'] as List<dynamic>),
      ppg: _doubleList(json['ppg'] as List<dynamic>),
      battery: json['battery'] as int?,
      status: json['status'] as String,
      sampleCount: json['sample_count'] as int,
    );
  }
}

class AnalysisResult {
  final int id;
  final String sessionId;
  final String modelName;
  final String modelVersion;
  final String status;
  final Map<String, dynamic> metrics;
  final Map<String, dynamic> signalQuality;
  final Map<String, dynamic> predictions;
  final List<Map<String, dynamic>> alerts;
  final String disclaimer;
  final DateTime createdAt;

  const AnalysisResult({
    required this.id,
    required this.sessionId,
    required this.modelName,
    required this.modelVersion,
    required this.status,
    required this.metrics,
    required this.signalQuality,
    required this.predictions,
    required this.alerts,
    required this.disclaimer,
    required this.createdAt,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      id: json['id'] as int,
      sessionId: json['session_id'] as String,
      modelName: json['model_name'] as String,
      modelVersion: json['model_version'] as String,
      status: json['status'] as String,
      metrics: Map<String, dynamic>.from(json['metrics'] as Map),
      signalQuality: Map<String, dynamic>.from(json['signal_quality'] as Map),
      predictions: Map<String, dynamic>.from(json['predictions'] as Map),
      alerts: (json['alerts'] as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      disclaimer: json['disclaimer'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.parse(value as String);
}

List<double> _doubleList(List<dynamic> values) {
  return values.map((value) => (value as num).toDouble()).toList();
}
