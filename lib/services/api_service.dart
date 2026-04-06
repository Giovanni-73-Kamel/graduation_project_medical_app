import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8000';

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
      String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      body: {
        'username': username,
        'password': password,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await saveToken(data['access_token']);
      return data;
    } else {
      throw Exception(
          json.decode(response.body)['detail'] ?? 'Failed to login');
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
        'doctor_name': doctorName,
        'doctor_email': doctorEmail,
        'doctor_phone': doctorPhone,
        'emergency_name': emergencyName,
        'emergency_email': emergencyEmail,
        'emergency_phone': emergencyPhone,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception(
          json.decode(response.body)['detail'] ?? 'Failed to sign up');
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
      Uri.parse('$baseUrl/reminders/'),
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
    int id, Map<String, dynamic> reminderData) async {
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
      Uri.parse('$baseUrl/reminders/$id'),
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
  static Future<void> updateContact(int id, Map<String, dynamic> contactData) async {
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
}
