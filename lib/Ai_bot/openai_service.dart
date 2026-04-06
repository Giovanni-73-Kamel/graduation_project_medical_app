import 'package:http/http.dart' as http;
import 'dart:convert';

class OpenAIService {
  // ⚠️ SECURITY WARNING: Never hardcode API keys in production!
  // Use environment variables or a secure backend service instead
  static const String _apiKey = 'YOUR_NEW_API_KEY_HERE';  // Replace with your new API key
  static const String _apiUrl = 'https://api.openai.com/v1/chat/completions';
  
  // Rate limiting: Track last request time
  DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(seconds: 20); // 20 seconds between requests

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
      print('🔄 Sending message to OpenAI: $message');
      
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a helpful medical assistant. Be empathetic, supportive, and provide general health advice. Keep responses concise (under 100 words). Always remind users to consult healthcare professionals for serious concerns.'
            },
            {
              'role': 'user',
              'content': message
            }
          ],
          'max_tokens': 100, // Reduced to save on costs and tokens
          'temperature': 0.7,
        }),
      );

      print('📡 Response Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        _lastRequestTime = DateTime.now(); // Update last request time
        final data = jsonDecode(response.body);
        final reply = data['choices'][0]['message']['content'].toString().trim();
        print(' OpenAI Response: $reply');
        return reply;
        
      } else if (response.statusCode == 401) {
        print(' API key authentication failed');
        print('Response: ${response.body}');
        return ' API key error. Please verify your OpenAI API key is valid and has not been revoked.';
        
      } else if (response.statusCode == 429) {
        print(' Rate limit exceeded');
        final data = jsonDecode(response.body);
        print('Error details: $data');
        
        // Check if it's a quota issue
        if (data['error']?['message']?.toString().contains('quota') ?? false) {
          return ' Your OpenAI account has exceeded its quota. Please:\n\n1. Check your billing at platform.openai.com\n2. Add a payment method\n3. Ensure you have available credits';
        }
        
        return '⏱️ Rate limit exceeded. Please:\n\n1. Wait 60 seconds before trying again\n2. Check your usage tier at platform.openai.com\n3. Consider upgrading your account';
        
      } else if (response.statusCode == 403) {
        print(' Forbidden - possible region or billing issue');
        return ' Access forbidden. Please check:\n\n1. Your account billing status\n2. Your API key permissions\n3. Your account standing at platform.openai.com';
        
      } else {
        print(' API Error: ${response.statusCode}');
        print('Response Body: ${response.body}');
        final data = jsonDecode(response.body);
        final errorMessage = data['error']?['message'] ?? 'Unknown error';
        return ' API Error (${response.statusCode}):\n$errorMessage';
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
  
  // Method to check if API key is configured
  bool isConfigured() {
    return _apiKey != 'YOUR_NEW_API_KEY_HERE' && _apiKey.isNotEmpty;
  }
}