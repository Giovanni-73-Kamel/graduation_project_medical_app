import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:medical/config/app_config.dart';

class OpenAIService {
  static String get _apiUrl => '${AppConfig.backendBaseUrl}/chat';

  DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(seconds: 20);

  Future<String> sendMessage(String message) async {
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
      if (timeSinceLastRequest < _minRequestInterval) {
        final waitTime = _minRequestInterval - timeSinceLastRequest;
        debugPrint(
          'Rate limit protection: waiting ${waitTime.inSeconds} seconds',
        );
        return 'Please wait ${waitTime.inSeconds} seconds before sending another message.';
      }
    }

    try {
      debugPrint('Sending message to backend chatbot: $message');

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': message}),
      );

      debugPrint('Response Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        _lastRequestTime = DateTime.now();
        final data = jsonDecode(response.body);
        final reply =
            data['reply']?.toString().trim() ??
            'Sorry, no reply from the chatbot.';
        debugPrint('Backend chatbot response: $reply');
        return reply;
      }

      debugPrint('Backend chatbot error: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');
      try {
        final data = jsonDecode(response.body);
        final errorMessage =
            data['error'] ?? data['detail'] ?? 'Unknown backend error';
        return 'Chatbot error (${response.statusCode}): $errorMessage';
      } catch (_) {
        return 'Chatbot error (${response.statusCode}): ${response.body.isEmpty ? 'Empty response' : response.body}';
      }
    } on http.ClientException catch (e) {
      debugPrint('Network error: $e');
      return 'Network error. Please check your internet connection.';
    } on FormatException catch (e) {
      debugPrint('JSON parsing error: $e');
      return 'Invalid response from server. Please try again.';
    } catch (e) {
      debugPrint('Unexpected error: $e');
      return 'Unexpected error: ${e.toString()}';
    }
  }
}
