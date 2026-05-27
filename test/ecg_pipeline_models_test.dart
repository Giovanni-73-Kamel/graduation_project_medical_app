import 'package:flutter_test/flutter_test.dart';
import 'package:medical/models/ecg_pipeline_models.dart';

void main() {
  test('MonitoringSession parses backend JSON', () {
    final session = MonitoringSession.fromJson({
      'id': 1,
      'session_id': 'session_123',
      'device_id': 'device_001',
      'sampling_rate': 250,
      'status': 'active',
      'started_at': '2026-05-13T10:30:00Z',
      'ended_at': null,
    });

    expect(session.sessionId, 'session_123');
    expect(session.deviceId, 'device_001');
    expect(session.samplingRate, 250);
  });

  test('RawReading parses ECG and PPG arrays as doubles', () {
    final reading = RawReading.fromJson({
      'id': 10,
      'device_id': 'device_001',
      'session_id': 'session_123',
      'timestamp': '2026-05-13T10:30:00Z',
      'sampling_rate': 250,
      'ecg': [0.12, 0.15, 0.18],
      'ppg': [520, 525, 531],
      'battery': 90,
      'status': 'active',
      'sample_count': 3,
    });

    expect(reading.ecg, [0.12, 0.15, 0.18]);
    expect(reading.ppg, [520.0, 525.0, 531.0]);
    expect(reading.sampleCount, 3);
  });
}
