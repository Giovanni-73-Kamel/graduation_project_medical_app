class AppointmentModel {
  final int id;
  final String patientName;
  final String date;
  final String time;
  final String note;
  final String type; // 'checkup' | 'follow-up' | 'urgent'

  const AppointmentModel({
    required this.id,
    required this.patientName,
    required this.date,
    required this.time,
    required this.note,
    required this.type,
  });

  // Add fromJson factory for API integration
  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'] ?? 0,
      patientName:
          json['patient_name'] ?? json['patientName'] ?? 'Unknown Patient',
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      note: json['note'] ?? '',
      type: json['type'] ?? 'checkup',
    );
  }

  // Add toJson method for API integration
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_name': patientName,
      'date': date,
      'time': time,
      'note': note,
      'type': type,
    };
  }
}

// ── Dummy appointments ──────────────────────────────────────────────────────
final List<AppointmentModel> dummyAppointments = [
  const AppointmentModel(
    id: 1,
    patientName: 'Sarah Johnson',
    date: 'Apr 5, 2026',
    time: '09:00 AM',
    note: 'Routine annual check-up and blood panel review.',
    type: 'checkup',
  ),
  const AppointmentModel(
    id: 2,
    patientName: 'Michael Chen',
    date: 'Apr 5, 2026',
    time: '10:30 AM',
    note: 'Follow-up on hypertension medication adjustment.',
    type: 'follow-up',
  ),
  const AppointmentModel(
    id: 3,
    patientName: 'Amira Hassan',
    date: 'Apr 6, 2026',
    time: '11:00 AM',
    note: 'First consultation, chest pain complaint.',
    type: 'urgent',
  ),
  const AppointmentModel(
    id: 4,
    patientName: 'Robert Davies',
    date: 'Apr 7, 2026',
    time: '02:00 PM',
    note: 'Post-surgery recovery assessment.',
    type: 'follow-up',
  ),
  const AppointmentModel(
    id: 5,
    patientName: 'Fatima Al-Sayed',
    date: 'Apr 8, 2026',
    time: '03:30 PM',
    note: 'Diabetes management and diet counselling.',
    type: 'checkup',
  ),
  const AppointmentModel(
    id: 6,
    patientName: 'Carlos Rivera',
    date: 'Apr 9, 2026',
    time: '08:30 AM',
    note: 'ECG results review and prescription renewal.',
    type: 'follow-up',
  ),
];
