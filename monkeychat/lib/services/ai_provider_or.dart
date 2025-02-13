import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:mime/mime.dart';

import 'package:monkeychat/services/ai_provider.dart';
import 'package:monkeychat/services/settings_service.dart';
import '../database/database_helper.dart';
import '../models/llm.dart';

// What a model on OR is capable of
class ORModelCapabilities {
  bool supportsTextInput = false;
  bool supportsImageInput = false;
  bool supportsTextOutput = false;
  bool supportsImageOutput = false;
}

class AIProviderOpenrouter extends AIProvider {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final _apiUrl = 'https://openrouter.ai/api/v1';
  final _frontendUrl = 'https://openrouter.ai/api/frontend';
  final SettingsService _settingsService = SettingsService();

  Future<List<LLModel>> _getCachedModels() async {
    return await _dbHelper.getCachedModels();
  }

  ORModelCapabilities _decodeCapabilities(String ioString) {
    final parts = ioString.split('->').map((e) => e.trim()).toList();
      if (parts.length != 2) {
        throw ArgumentError('Invalid format: Use "input_types->output_types"');
      }

      final inputTypes = parts[0]
          .split('+')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final outputTypes = parts[1]
          .split('+')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (inputTypes.isEmpty || outputTypes.isEmpty) {
        throw ArgumentError('Must specify at least one input and output type');
      }

      const allowedTypes = {'text', 'image'};

      void validateTypes(List<String> types, String category) {
        for (final type in types) {
          if (!allowedTypes.contains(type)) {
            throw ArgumentError('Invalid $category type: $type');
          }
        }
      }

      validateTypes(inputTypes, 'input');
      validateTypes(outputTypes, 'output');

      final config = ORModelCapabilities();

      // Process input types
      for (final type in inputTypes) {
        switch (type) {
          case 'text':
            config.supportsTextInput = true;
            break;
          case 'image':
            config.supportsImageInput = true;
            break;
        }
      }

      // Process output types
      for (final type in outputTypes) {
        switch (type) {
          case 'text':
            config.supportsTextOutput = true;
            break;
          case 'image':
            config.supportsImageOutput = true;
            break;
        }
      }

      return config;
  }

  // see: https://openrouter.ai/api/frontend/models
  LLModel? _ingestLLMInfo(Map<String, dynamic> json) {
    try {
      final permaslug = json['slug'];
      final shortName = json['short_name'];
      final descriptionJson = json['description'];
      final endpoint = json['endpoint'];
      final capabilities = json['modality'];

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
      if (capabilities == null) {
        throw ArgumentError('modality is missing');
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

      ORModelCapabilities modelCapabilities = _decodeCapabilities(capabilities);

      // Iterate the supported parameters
      List<String> supportedParams = json['supported_params'] != null
          ? List<String>.from(json['supported_params'])
          : <String>[];

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
        supportsImageInput: modelCapabilities.supportsImageInput,
        supportsImageOutput: modelCapabilities.supportsImageOutput,
        tunableParameters: supportedParams,
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


  @override
  Future<String> fetchImageURL(String modelId) async {
    final models = await getModels();
    final model = models.where((element) => element.id == modelId).toList();
    return model[0].iconUrl;
  }

  @override
  Stream<String> streamResponse(
    String modelId,
    String question,
    {String? imagePath}
  ) async* {
    final url = Uri.parse('$_apiUrl/chat/completions');
    final apiKey = await _settingsService.getApiKey();
    if (apiKey == null) {
      print('API key not set');
      return;
    }

    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    // Prepare message content
    dynamic messageContent;
    if (imagePath != null) {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final mimeType = lookupMimeType(imagePath) ?? 'image/jpeg';

      if (!mimeType.startsWith('image/')) {
        throw Exception('Unsupported file type: $mimeType');
      }

      final base64Image = base64Encode(bytes);
      final dataUri = 'data:$mimeType;base64,$base64Image';

      messageContent = [
        {
          'type': 'text',
          'text': question
        },
        {
          'type': 'image_url',
          'image_url': {
            'url': dataUri,
            'detail': 'auto' // You can modify this based on needs
          }
        }
      ];
    } else {
      messageContent = question;
    }

    final payload = {
      'model': modelId,
      'messages': [
        {
          'role': 'user',
          'content': messageContent
        }
      ],
      'stream': true,
    };

    // Rest of the original stream handling remains the same
    final request = http.Request('POST', url)
      ..headers.addAll(headers)
      ..body = jsonEncode(payload);

    final streamedResponse = await request.send();

    if (streamedResponse.statusCode == 200) {
      String buffer = '';

      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        buffer += chunk;

        while (true) {
          final lineEnd = buffer.indexOf('\n');
          if (lineEnd == -1) break;

          final line = buffer.substring(0, lineEnd).trim();
          buffer = buffer.substring(lineEnd + 1);

          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data == '[DONE]') return;

            try {
              final dataObj = jsonDecode(data);
              final content = dataObj['choices'][0]['delta']['content'];
              if (content != null) yield content;
            } catch (e) {
              // Ignore JSON decode errors
            }
          }
        }
      }
    } else {
      print('Request failed with status code: ${streamedResponse.statusCode}');
      throw Exception('Request failed with status code: ${streamedResponse.statusCode}');
    }
  }
}
