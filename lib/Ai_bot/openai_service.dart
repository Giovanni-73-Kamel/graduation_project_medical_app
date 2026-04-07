import 'package:http/http.dart' as http;
import 'dart:convert';

class OpenAIService {
  // Backend chatbot endpoint
  static const String _baseUrl = 'http://10.0.2.2:8000';
  static const String _apiUrl = '$_baseUrl/chat';

  // Rate limiting: Track last request time
  DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(
    seconds: 20,
  ); // 20 seconds between requests

  Future<String> sendMessage(String message) async {
    // Check rate limiting
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
      if (timeSinceLastRequest < _minRequestInterval) {
        final waitTime = _minRequestInterval - timeSinceLastRequest;
        print('⏳ Rate limit protection: waiting ${waitTime.inSeconds} seconds');
        return 'Please wait ${waitTime.inSeconds} seconds before sending another message.';
      }
    }

    try {
      print('🔄 Sending message to backend chatbot: $message');

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': message}),
      );

      print('📡 Response Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        _lastRequestTime = DateTime.now();
        final data = jsonDecode(response.body);
        final reply =
            data['reply']?.toString().trim() ??
            'Sorry, no reply from the chatbot.';
        print(' Backend chatbot response: $reply');
        return reply;
      } else {
        print(' Backend chatbot error: ${response.statusCode}');
        print('Response Body: ${response.body}');
        try {
          final data = jsonDecode(response.body);
          final errorMessage =
              data['error'] ?? data['detail'] ?? 'Unknown backend error';
          return 'Chatbot error (${response.statusCode}): $errorMessage';
        } catch (_) {
          return 'Chatbot error (${response.statusCode}): ${response.body.isEmpty ? 'Empty response' : response.body}';
        }
      }
    } on http.ClientException catch (e) {
      print(' Network error: $e');
      return ' Network error. Please check your internet connection.';
    } on FormatException catch (e) {
      print(' JSON parsing error: $e');
      return ' Invalid response from server. Please try again.';
    } catch (e) {
      print(' Unexpected error: $e');
      return ' Unexpected error: ${e.toString()}';
    }
  }
}
