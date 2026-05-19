import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // static const String baseUrl =
  //     'http://10.0.0.190:8000'; // Your computer's WiFi IP
  static const String baseUrl = 'http://10.0.2.2:8000'; // bta3 l emulator
  // ─────────────────────────────────────────────
  // Token helpers
  // ─────────────────────────────────────────────

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  // ─────────────────────────────────────────────
  // Auth API
  // ─────────────────────────────────────────────

  /// Login with email + password. Saves the bearer token on success.
  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login/'),
      body: {'username': username, 'password': password},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await saveToken(data['access_token']);
      return data;
    } else if (response.statusCode == 307 || response.statusCode == 308) {
      final location = response.headers['location'] ?? 'unknown';
      throw Exception(
        'Login request redirected to $location (HTTP ${response.statusCode}). Check the API path.',
      );
    } else {
      try {
        throw Exception(
          json.decode(response.body)['detail'] ?? 'Failed to login',
        );
      } catch (e) {
        throw Exception(
          'Failed to login: ${response.statusCode} - ${response.body.isEmpty ? 'Empty response' : response.body}',
        );
      }
    }
  }

  /// Register a new user account.
  static Future<void> signUp({
    required String username,
    required String email,
    required String password,
    String? role,
    String? phoneNumber,
    String? dateOfBirth,
    String? age,
    String? height,
    String? weight,
    String? doctorName,
    String? doctorEmail,
    String? doctorPhone,
    String? emergencyName,
    String? emergencyEmail,
    String? emergencyPhone,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'email': email,
        'password': password,
        'role': role ?? 'patient',
        'phone_number': phoneNumber,
        'date_of_birth': dateOfBirth,
        'age': age,
        'height': height,
        'weight': weight,
        'doctor_name': doctorName,
        'doctor_email': doctorEmail,
        'doctor_phone': doctorPhone,
        'emergency_name': emergencyName,
        'emergency_email': emergencyEmail,
        'emergency_phone': emergencyPhone,
      }),
    );

    if (response.statusCode == 307 || response.statusCode == 308) {
      final location = response.headers['location'] ?? 'unknown';
      throw Exception(
        'Signup request redirected to $location (HTTP ${response.statusCode}). Check the API path and trailing slash.',
      );
    }

    if (response.statusCode != 201) {
      try {
        final error =
            json.decode(response.body)['detail'] ?? 'Failed to sign up';
        throw Exception(error);
      } catch (e) {
        throw Exception(
          'Failed to sign up: ${response.statusCode} - ${response.body.isEmpty ? 'Empty response' : response.body}',
        );
      }
    }

    // Save token after successful signup
    try {
      final data = json.decode(response.body);
      if (data['access_token'] != null) {
        await saveToken(data['access_token']);
      }
    } catch (e) {
      // Continue even if token extraction fails
    }
  }

  // ─────────────────────────────────────────────
  // Profile API  →  GET /users/me  |  PUT /users/me
  // ─────────────────────────────────────────────

  /// Fetch the currently logged-in user's profile.
  static Future<Map<String, dynamic>> getUserProfile() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No authentication token found. Please login first.');
    }
    final response = await http.get(
      Uri.parse('$baseUrl/users/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load profile');
    }
  }

  /// Update the currently logged-in user's profile fields.
  static Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/users/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(data),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update profile');
    }
  }

  // ─────────────────────────────────────────────
  // Reminders API  →  /reminders/
  // ─────────────────────────────────────────────

  /// Get all reminders for the current user.
  static Future<List<dynamic>> getReminders() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/reminders/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load reminders');
    }
  }

  /// Create a new reminder.
  static Future<void> createReminder(Map<String, dynamic> reminderData) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/reminders/createreminders'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(reminderData),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to create reminder');
    }
  }

  /// Update an existing reminder by [id].
  static Future<void> updateReminder(
    int id,
    Map<String, dynamic> reminderData,
  ) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/reminders/$id/'), // ✅ FIXED (added /)
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(reminderData),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
        json.decode(response.body)['detail'] ?? 'Failed to update reminder',
      );
    }
  }

  /// Delete a reminder by [id].
  static Future<void> deleteReminder(int id) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/reminders/deletereminder/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete reminder');
    }
  }

  // ─────────────────────────────────────────────
  // Contacts API  →  /contacts/
  // ─────────────────────────────────────────────

  /// Get all contacts for the current user.
  static Future<List<dynamic>> getContacts() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/contacts/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load contacts');
    }
  }

  /// update a certain contact
  static Future<void> updateContact(
    int id,
    Map<String, dynamic> contactData,
  ) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/contacts/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(contactData),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update contact');
    }
  }

  /// Create a new contact.
  static Future<void> createContact(Map<String, dynamic> contactData) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/contacts/createcontacts'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(contactData),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to create contact');
    }
  }

  /// Delete a contact by [id].
  static Future<void> deleteContact(int id) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/contacts/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete contact');
    }
  }

  // ─────────────────────────────────────────────
  // Appointments API  →  /appointments/
  // ─────────────────────────────────────────────

  /// Get all appointments for the current user (doctor or patient).
  static Future<List<dynamic>> getAppointments() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/appointments/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load appointments');
    }
  }

  /// Create a new appointment.
  static Future<Map<String, dynamic>> createAppointment(
    Map<String, dynamic> appointmentData,
  ) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/appointments/createappointment/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(appointmentData),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create appointment');
    }
  }

  /// Update an existing appointment by [id].
  static Future<void> updateAppointment(
    int id,
    Map<String, dynamic> appointmentData,
  ) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/appointments/$id/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(appointmentData),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to update appointment');
    }
  }

  /// Delete an appointment by [id].
  static Future<void> deleteAppointment(int id) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/appointments/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete appointment');
    }
  }

  // ─────────────────────────────────────────────
  // Patients API  →  /patients/
  // ─────────────────────────────────────────────

  /// Get all patients for the current doctor.
  static Future<List<dynamic>> getPatients() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/patients/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load patients');
    }
  }

  /// Get patient details by [id].
  static Future<Map<String, dynamic>> getPatientById(int id) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/patients/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load patient details');
    }
  }

  /// Create a new patient profile.
  static Future<Map<String, dynamic>> createPatient(
    Map<String, dynamic> patientData,
  ) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/patients/createpatients'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(patientData),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create patient');
    }
  }

  /// Update patient information by [id].
  static Future<void> updatePatient(
    int id,
    Map<String, dynamic> patientData,
  ) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/patients/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(patientData),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to update patient');
    }
  }

  // ─────────────────────────────────────────────
  // Medical Records API  →  /medical-records/
  // ─────────────────────────────────────────────

  /// Get medical records for a patient by [patientId].
  static Future<List<dynamic>> getMedicalRecords(int patientId) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/medical-records/patient/$patientId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load medical records');
    }
  }

  /// Create or update medical records for a patient.
  static Future<Map<String, dynamic>> createMedicalRecord(
    Map<String, dynamic> recordData,
  ) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/medical-records/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(recordData),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create medical record');
    }
  }

  /// Update medical record by [id].
  static Future<void> updateMedicalRecord(
    int id,
    Map<String, dynamic> recordData,
  ) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/medical-records/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(recordData),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to update medical record');
    }
  }

  // ─────────────────────────────────────────────
  // Prescriptions API  →  /prescriptions/
  // ─────────────────────────────────────────────

  /// Get prescriptions for an appointment by [appointmentId].
  static Future<List<dynamic>> getPrescriptionsByAppointment(
    int appointmentId,
  ) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/prescriptions/appointment/$appointmentId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load prescriptions');
    }
  }

  /// Create a new prescription.
  static Future<Map<String, dynamic>> createPrescription(
    Map<String, dynamic> prescriptionData,
  ) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/prescriptions/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(prescriptionData),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create prescription');
    }
  }

  /// Update prescription by [id].
  static Future<void> updatePrescription(
    int id,
    Map<String, dynamic> prescriptionData,
  ) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/prescriptions/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(prescriptionData),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to update prescription');
    }
  }

  // ─────────────────────────────────────────────
  // Lab Results API  →  /lab-results/
  // ─────────────────────────────────────────────

  /// Get lab results for an appointment by [appointmentId].
  static Future<List<dynamic>> getLabResultsByAppointment(
    int appointmentId,
  ) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/lab-results/appointment/$appointmentId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load lab results');
    }
  }

  /// Create a new lab result.
  static Future<Map<String, dynamic>> createLabResult(
    Map<String, dynamic> labResultData,
  ) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/lab-results/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(labResultData),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create lab result');
    }
  }

  // ─────────────────────────────────────────────
  // Doctors API  →  /doctors/
  // ─────────────────────────────────────────────

  /// Get all doctors (for patient selection).
  static Future<List<dynamic>> getDoctors({String? search}) async {
    final token = await getToken();
    final url = search != null
        ? Uri.parse('$baseUrl/doctors?search=$search')
        : Uri.parse('$baseUrl/doctors/');

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load doctors');
    }
  }

  /// Get doctor details by [id].
  static Future<Map<String, dynamic>> getDoctorById(int id) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/doctors/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load doctor details');
    }
  }

  /// Create a new doctor (for patient use).
  static Future<Map<String, dynamic>> createDoctor({
    required String name,
    required String email,
    required String phoneNumber,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/doctors/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'name': name,
        'email': email,
        'phone_number': phoneNumber,
      }),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create doctor');
    }
  }

  /// Update user's assigned doctor.
  static Future<void> updateUserDoctor(int doctorId) async {
    final token = await getToken();
    final response = await http.patch(
      Uri.parse('$baseUrl/users/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'doctor_id': doctorId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update assigned doctor');
    }
  }

  // ─────────────────────────────────────────────
  // Clinics API  →  /clinics/
  // ─────────────────────────────────────────────

  /// Get all clinics.
  static Future<List<dynamic>> getClinics() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/clinics/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load clinics');
    }
  }

  // ─────────────────────────────────────────────
  // Medications API  →  /medications/
  // ─────────────────────────────────────────────

  /// Get all medications.
  static Future<List<dynamic>> getMedications() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/medications/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load medications');
    }
  }

  /// Search medications by [query].
  static Future<List<dynamic>> searchMedications(String query) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/medications/search?q=$query'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to search medications');
    }
  }

  // ─────────────────────────────────────────────
  // Admin API  →  /admin/
  // ─────────────────────────────────────────────

  /// Get admin dashboard statistics.
  static Future<Map<String, dynamic>> getDashboardStats() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/admin/dashboard'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load dashboard stats');
    }
  }

  /// Get all users (admin only).
  static Future<List<dynamic>> getAllUsers() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/admin/users'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load users');
    }
  }

  // ─────────────────────────────────────────────
  // ECG / Heart Condition API  →  /ecg/
  // ─────────────────────────────────────────────

  /// GET /ecg/classifications
  ///
  /// Returns the list of ECG record-level classification definitions
  /// (NORM, MI, STTC, CD, HYP) from the backend.
  ///
  /// Falls back to [_localEcgClassifications] when the backend is not yet
  /// available, so the UI always has data to display.
  static Future<List<Map<String, dynamic>>> getEcgClassifications() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/ecg/classifications'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      }
    } catch (_) {
      // Backend not reachable – fall through to local data
    }
    return _localEcgClassifications;
  }

  /// GET /ecg/classification-levels
  ///
  /// Returns the beat-level and record-level classification groups used in
  /// the "Important Difference" section of the Heart Condition page.
  ///
  /// Falls back to [_localClassificationLevels] when the backend is not yet
  /// available.
  static Future<List<Map<String, dynamic>>> getClassificationLevels() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/ecg/classification-levels'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      }
    } catch (_) {
      // Backend not reachable – fall through to local data
    }
    return _localClassificationLevels;
  }

  /// GET /ecg/current-condition
  ///
  /// Returns the current dynamic heart condition for the user from the smartwatch.
  static Future<Map<String, dynamic>> getCurrentHeartCondition() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/ecg/current-condition'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (_) {
      // Backend not reachable – fall through to local data
    }
    return _localCurrentCondition;
  }

  // ── Local fallback data (mirrors expected backend JSON shape) ─────────────

  static const List<Map<String, dynamic>> _localEcgClassifications = [
    {
      'code': 'NORM',
      'label': 'Normal ECG',
      'description':
          "No clear abnormalities detected. The heart's electrical activity follows a healthy, regular pattern.",
      'color_hex': '#00C853',
      'icon_name': 'check_circle_outline',
    },
    {
      'code': 'MI',
      'label': 'Myocardial Infarction',
      'description':
          'Indicates a heart attack. Blood supply to part of the heart muscle has been blocked, causing damage.',
      'color_hex': '#E53935',
      'icon_name': 'warning_amber_rounded',
    },
    {
      'code': 'STTC',
      'label': 'ST/T Wave Changes',
      'description':
          'May suggest ischemia or early cardiac issues. Changes in the ST segment and T wave of the ECG.',
      'color_hex': '#FF6F00',
      'icon_name': 'show_chart',
    },
    {
      'code': 'CD',
      'label': 'Conduction Disturbance',
      'description':
          "Problems in the heart's electrical signal pathway, leading to abnormal timing of heartbeats.",
      'color_hex': '#7B1FA2',
      'icon_name': 'electric_bolt_outlined',
    },
    {
      'code': 'HYP',
      'label': 'Hypertrophy',
      'description':
          'Enlargement of the heart muscle, often due to prolonged high blood pressure or valve disease.',
      'color_hex': '#0288D1',
      'icon_name': 'favorite_border',
    },
  ];

  static const List<Map<String, dynamic>> _localClassificationLevels = [
    {
      'level_type': 'beat',
      'title': 'Beat-Level Classification',
      'subtitle': 'Classifies a single heartbeat',
      'codes': [
        {'code': 'N', 'color_hex': '#00C853'},
        {'code': 'S', 'color_hex': '#0288D1'},
        {'code': 'V', 'color_hex': '#E53935'},
        {'code': 'F', 'color_hex': '#FF6F00'},
        {'code': 'Q', 'color_hex': '#607D8B'},
      ],
    },
    {
      'level_type': 'record',
      'title': 'Record-Level Classification',
      'subtitle': 'Classifies the entire ECG recording',
      'codes': [
        {'code': 'NORM', 'color_hex': '#00C853'},
        {'code': 'MI',   'color_hex': '#E53935'},
        {'code': 'STTC', 'color_hex': '#FF6F00'},
        {'code': 'CD',   'color_hex': '#7B1FA2'},
        {'code': 'HYP',  'color_hex': '#0288D1'},
      ],
    },
  ];

static const Map<String, dynamic> _localCurrentCondition = {
   'code': 'HYP',
      'label': 'Hypertrophy',
      'description':
          'Enlargement of the heart muscle, often due to prolonged high blood pressure or valve disease.',
      'color_hex': '#0288D1',
      'icon_name': 'favorite_border',
  };
}
