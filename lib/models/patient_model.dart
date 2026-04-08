class PatientModel {
  final int id;
  final String name;
  final int age;
  final String email;
  final String phone;
  final String avatarInitials;
  final int heartRate;
  final String bloodPressure;
  final double temperature;

  const PatientModel({
    required this.id,
    required this.name,
    required this.age,
    required this.email,
    required this.phone,
    required this.avatarInitials,
    required this.heartRate,
    required this.bloodPressure,
    required this.temperature,
  });

  // Add fromJson factory for API integration
  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      id: json['id'] ?? 0,
      name: json['full_name'] ?? json['name'] ?? 'Unknown Patient',
      age: json['age'] ?? 0,
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      avatarInitials: _getInitials(
        json['full_name'] ?? json['name'] ?? 'Unknown',
      ),
      heartRate: json['heart_rate'] ?? 72,
      bloodPressure: json['blood_pressure'] ?? '120/80',
      temperature: (json['temperature'] ?? 36.6).toDouble(),
    );
  }

  // Add toJson method for API integration
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': name,
      'age': age,
      'email': email,
      'phone': phone,
      'heart_rate': heartRate,
      'blood_pressure': bloodPressure,
      'temperature': temperature,
    };
  }

  // Helper method to get initials
  static String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
  }
}

// ── Dummy patients ──────────────────────────────────────────────────────────
final List<PatientModel> dummyPatients = [
  const PatientModel(
    id: 1,
    name: 'Sarah Johnson',
    age: 34,
    email: 'sarah.johnson@email.com',
    phone: '+1 (555) 123-4567',
    avatarInitials: 'SJ',
    heartRate: 72,
    bloodPressure: '118/76',
    temperature: 36.6,
  ),
  const PatientModel(
    id: 2,
    name: 'Michael Chen',
    age: 47,
    email: 'mchen@email.com',
    phone: '+1 (555) 234-5678',
    avatarInitials: 'MC',
    heartRate: 88,
    bloodPressure: '135/85',
    temperature: 37.1,
  ),
  const PatientModel(
    id: 3,
    name: 'Amira Hassan',
    age: 29,
    email: 'amira.h@email.com',
    phone: '+20 (100) 345-6789',
    avatarInitials: 'AH',
    heartRate: 65,
    bloodPressure: '112/72',
    temperature: 36.4,
  ),
  const PatientModel(
    id: 4,
    name: 'Robert Davies',
    age: 61,
    email: 'rdavies@email.com',
    phone: '+44 (77) 456-7890',
    avatarInitials: 'RD',
    heartRate: 79,
    bloodPressure: '142/90',
    temperature: 37.3,
  ),
  const PatientModel(
    id: 5,
    name: 'Fatima Al-Sayed',
    age: 42,
    email: 'fatima.as@email.com',
    phone: '+971 (50) 567-8901',
    avatarInitials: 'FA',
    heartRate: 70,
    bloodPressure: '124/80',
    temperature: 36.8,
  ),
  const PatientModel(
    id: 6,
    name: 'Carlos Rivera',
    age: 55,
    email: 'carlos.r@email.com',
    phone: '+52 (55) 678-9012',
    avatarInitials: 'CR',
    heartRate: 84,
    bloodPressure: '138/88',
    temperature: 37.0,
  ),
];
