import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import 'package:monkeychat/services/ai_provider.dart';
import 'package:monkeychat/services/settings_service.dart';
import 'dart:convert';
import '../database/database_helper.dart';
import '../models/llm.dart';

class AIProviderOpenrouter extends AIProvider {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _apiUrl = 'https://openrouter.ai/api/v1';
  final _frontendUrl = 'https://openrouter.ai/api/frontend';
  final SettingsService _settingsService = SettingsService();

  Future<List<LLModel>> _getCachedModels() async {
    return await _dbHelper.getCachedModels();
  }

  // see: https://openrouter.ai/api/frontend/models
  LLModel? _ingestLLMInfo(Map<String, dynamic> json) {
    try {
      final permaslug = json['slug'];
      final shortName = json['short_name'];
      final descriptionJson = json['description'];
      final endpoint = json['endpoint'];

      // Validate required fields
      if (permaslug == null) {
        throw ArgumentError('permaslug is missing');
      }
      if (shortName == null) {
        throw ArgumentError('short_name is missing');
      }
      if (descriptionJson == null) {
        throw ArgumentError('description is missing');
      }

      // If the endpoint is null, the model is no longer available by any providers, so we exclude it.
      if (endpoint == null) {
        return null;
      }

      const int maxDescriptionLength = 50;

      // Handle description (ensure it's a string)
      String description;
      if (descriptionJson is String) {
        description = descriptionJson.length > maxDescriptionLength
            ? descriptionJson.substring(0, maxDescriptionLength)
            : descriptionJson;

      } else {
        description = "No Description provided";
        if (kDebugMode) {
          print(
              'Error: Invalid description format. Expected String, got: ${descriptionJson.runtimeType}');
        }
      }

      // Don't ask me why...
      String iconUrl = "";
      if (endpoint != null) {
        iconUrl = endpoint['provider_info']['icon']['url'];

        // if the url doesnt start with a https, the image is stored on OR, so add the OR base URL
        if (!iconUrl.startsWith('https')) {
          iconUrl = 'https://openrouter.ai$iconUrl';
        }
      }

      return LLModel(
        id: permaslug,
        name: shortName,
        description: description,
        provider: "NOPE",
        iconUrl: iconUrl,
        capabilities: <String, dynamic>{},
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Stack trace: $stackTrace');
      }
      return null;
    }
  }

   @override
  Future<List<LLModel>> getModels({bool forceRefresh = false}) async {
    final cachedModels = await _getCachedModels();
    if (cachedModels.isNotEmpty && !forceRefresh) {
      return cachedModels;
    }

    final response = await http.get(
      Uri.parse('$_frontendUrl/models'),
    );
    //print('Response: ${response.body}');

    // This is a multiple MB json, we try to cache it at all costs.
    if (response.statusCode == 200) {
      try {
        final decodedBody = utf8.decode(response.bodyBytes);
        final models = (jsonDecode(decodedBody)['data'] as List)
            .map((e) => _ingestLLMInfo(e))
            .toList();

        // Deduplicate the models based on their ID (permaslug)
        final uniqueModels = <LLModel>[];
        final seenIds = <String>{};

        for (final model in models) {
          if (model == null) {
            continue;
          }
          if (!seenIds.contains(model.id)) {
            uniqueModels.add(model);
            seenIds.add(model.id);
          }
        }
        await _dbHelper.cacheModels(uniqueModels);
        return uniqueModels;
      } catch (e) {
        print('Error parsing models: $e');
        return cachedModels;
      }
    }

    return cachedModels;
  }

  // Helper method to convert a string to PascalCase
  String _toPascalCase(String input) {
    // Split into parts (e.g., "deep_seek" -> ["deep", "seek"])
    List<String> parts = input.split(RegExp(r'[_\s]'));

    // Capitalize the first letter of each part and concatenate
    String pascalCase = parts.map((part) {
      if (part.isEmpty) return part;
      return part[0].toUpperCase() + part.substring(1).toLowerCase();
    }).join();

    return pascalCase;
  }

  @override
  Future<String> fetchImageURL(String modelId) async {
    final nameSubset = modelId.contains('/') ? modelId.split('/')[0] : modelId;
    final pascalCaseName = _toPascalCase(nameSubset);
    return "https://openrouter.ai/images/icons/$pascalCaseName.png";
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
