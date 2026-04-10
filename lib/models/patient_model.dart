class PatientModel {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String avatarInitials;

  const PatientModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.avatarInitials,
  });

  // Add fromJson factory for API integration
  factory PatientModel.fromJson(Map<String, dynamic> json) {
    final fullName = json['name'] ?? json['username'] ?? 'Unknown Patient';
    return PatientModel(
      id: json['id'] ?? 0,
      name: fullName,
      email: json['email'] ?? '',
      phone: json['phone_number'] ?? json['phone'] ?? '',
      avatarInitials: _getInitials(fullName),
    );
  }

  // Add toJson method for API integration
  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'email': email, 'phone': phone};
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
    email: 'sarah.johnson@email.com',
    phone: '+1 (555) 123-4567',
    avatarInitials: 'SJ',
  ),
  const PatientModel(
    id: 2,
    name: 'Michael Chen',
    email: 'mchen@email.com',
    phone: '+1 (555) 234-5678',
    avatarInitials: 'MC',
  ),
  const PatientModel(
    id: 3,
    name: 'Amira Hassan',
    email: 'amira.h@email.com',
    phone: '+20 (100) 345-6789',
    avatarInitials: 'AH',
  ),
  const PatientModel(
    id: 4,
    name: 'Robert Davies',
    email: 'rdavies@email.com',
    phone: '+44 (77) 456-7890',
    avatarInitials: 'RD',
  ),
  const PatientModel(
    id: 5,
    name: 'Fatima Al-Sayed',
    email: 'fatima.as@email.com',
    phone: '+971 (50) 567-8901',
    avatarInitials: 'FA',
  ),
  const PatientModel(
    id: 6,
    name: 'Carlos Rivera',
    email: 'carlos.r@email.com',
    phone: '+52 (55) 678-9012',
    avatarInitials: 'CR',
  ),
];
