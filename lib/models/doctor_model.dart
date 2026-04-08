class DoctorModel {
  final int id;
  final String name;
  final String email;
  final String phoneNumber;

  const DoctorModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
  });

  // Add fromJson factory for API integration
  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    return DoctorModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unknown Doctor',
      email: json['email'] ?? '',
      phoneNumber: json['phone_number'] ?? json['phoneNumber'] ?? '',
    );
  }

  // Add toJson method for API integration
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone_number': phoneNumber,
    };
  }

  @override
  String toString() {
    return name;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DoctorModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
