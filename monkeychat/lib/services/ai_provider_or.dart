import 'package:http/http.dart' as http;
import 'package:monkeychat/services/ai_provider.dart';
import 'package:monkeychat/services/settings_service.dart';
import 'dart:convert';
import '../database/database_helper.dart';
import '../models/llm_model.dart';

class AIProviderOpenrouter extends AIProvider {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _apiUrl = 'https://openrouter.ai/api/v1';
  final SettingsService _settingsService = SettingsService();

  Future<List<LLMModel>> _getCachedModels() async {
    return await _dbHelper.getCachedModels();
  }

  @override
  Future<List<LLMModel>> getModels({bool forceRefresh = false}) async {
    final cachedModels = await _getCachedModels();
    if (cachedModels.isNotEmpty && !forceRefresh) {
      return cachedModels;
    }

    final response = await http.get(
      Uri.parse('$_apiUrl/models'),
    );
    print('Response: ${response.body}');

    if (response.statusCode == 200) {
      final models = (jsonDecode(response.body)['data'] as List)
          .map((e) => LLMModel.fromJson(e))
          .toList();
      await _dbHelper.cacheModels(models);
      return models;
    }

    return cachedModels; // Return cached if available
  }

  @override
  Stream<String> streamResponse(String modelId, String question) async* {
    final url = Uri.parse('$_apiUrl/chat/completions'); // Fix the URL
    final apiKey = await _settingsService.getApiKey();
    if (apiKey == null) {
      print('API key not set');
      return;
    }

    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    final payload = {
      'model': modelId,
      'messages': [
        {'role': 'user', 'content': question}
      ],
      'stream': true,
    };

    final request = http.Request('POST', url)
      ..headers.addAll(headers)
      ..body = jsonEncode(payload);

    final streamedResponse = await request.send();

    if (streamedResponse.statusCode == 200) {
      String buffer = '';

      await for (final chunk
          in streamedResponse.stream.transform(utf8.decoder)) {
        buffer += chunk;

        while (true) {
          final lineEnd = buffer.indexOf('\n');
          if (lineEnd == -1) break;

          final line = buffer.substring(0, lineEnd).trim();
          buffer = buffer.substring(lineEnd + 1);

          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data == '[DONE]') {
              return;
            }

            try {
              final dataObj = jsonDecode(data);
              final content = dataObj['choices'][0]['delta']['content'];
              if (content != null) {
                yield content; // Yield the content as a stream event
              }
            } catch (e) {
              // Ignore JSON decode errors
            }
          }
        }
      }
    } else {
      print('Request failed with status code: ${streamedResponse.statusCode}');
      throw Exception(
          'Request failed with status code: ${streamedResponse.statusCode}');
    }
  }
}
