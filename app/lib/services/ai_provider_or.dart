import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:mime/mime.dart';

import 'package:monkeychat/services/ai_provider.dart';
import 'package:monkeychat/services/settings_service.dart';
import '../database/local_db.dart';
import '../models/llm.dart';

// What a model on OR is capable of
class ORModelCapabilities {
  bool supportsTextInput = false;
  bool supportsImageInput = false;
  bool supportsTextOutput = false;
  bool supportsImageOutput = false;
}

class AIProviderOpenrouter extends AIProvider {
  final LocalDb _dbHelper = LocalDb.instance;
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

  final List<String> additionalKnownReasoningModels = [
    // *SOME* AI Vendors insist on not showing the COT
    "deepseek/deepseek-r1",
    "openai/o3-mini-high",
    "openai/o3-mini",
    "openai/o1-mini-2024-09-12",
    "openai/o1-mini",
    "openai/o1",
    "openai/o1-preview",
    "openai/o1-preview-2024-09-12"
  ];

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

      List<String> supportedParams = [];
      if (endpoint != null && endpoint.containsKey('supported_parameters')) {
        supportedParams = List<String>.from(endpoint['supported_parameters']);
      }

      /*bool doesReasoing = supportedParams.contains('include_reasoning');
      if (doesReasoing) {
        print('Model $shortName supports reasoning');
      }*/

      // Don't ask me why...
      String iconUrl = "";
      if (endpoint != null) {
        iconUrl = endpoint['provider_info']['icon']['url'];

        // if the url doesnt start with a https, the image is stored on OR, so add the OR base URL
        if (!iconUrl.startsWith('https')) {
          iconUrl = 'https://openrouter.ai$iconUrl';
        }
      }

      bool doesReasoning = endpoint["supports_reasoning"];
      if (!doesReasoning) {
        doesReasoning = additionalKnownReasoningModels.contains(permaslug);
      }

      return LLModel(
        id: permaslug,
        name: shortName,
        description: description,
        provider: "NOPE",
        iconUrl: iconUrl,
        supportsImageInput: modelCapabilities.supportsImageInput,
        supportsImageOutput: modelCapabilities.supportsImageOutput,
        supportsReasoningDisplay: endpoint["supports_reasoning"],
        supportsReasoning: doesReasoning,
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

  // modelID is the model to use
  // question is the user input
  // params are the parameters to pass to the model (e.g. temperature: 0.6)
  // attachmentPaths are the paths to any attachments. they can be images, or pdfs for example
  @override
  Stream<TokenEvent> streamResponse(String modelId, String question,
      Map<String, dynamic> params, List<String>? attachmentPaths) async* {
    final url = Uri.parse('$_apiUrl/chat/completions');
    final apiKey = await _settingsService.getApiKey();
    if (apiKey == null) {
      print('API key not set');
      return;
    }

    print('Params: $params');

    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    // Prepare message content
    List<Map<String, dynamic>> messageContent = []; // Changed to dynamic

    if (attachmentPaths != null && attachmentPaths.isNotEmpty) {
      // Add the text prompt is available
      if (question.isNotEmpty) {
        messageContent.add({'type': 'text', 'text': question});
      }
      // read attachments
      for (String attachmentPath in attachmentPaths) {
        final file = File(attachmentPath);
        final bytes = await file.readAsBytes();
        final mimeType = lookupMimeType(attachmentPath) ?? 'image/jpeg';

        if (!mimeType.startsWith('image/')) {
          //TODO: Add support for PDFs and other doc types
          print('Unsupported file type: $mimeType');
          continue;
        }

        final base64Image = base64Encode(bytes);
        final dataUri = 'data:$mimeType;base64,$base64Image';

        messageContent.add({
          'type': 'image_url',
          'image_url': {
            'url': dataUri,
            'detail': 'auto' // You can modify this based on needs
          }
        });
      }
    } else {
      messageContent = [
        {'type': 'text', 'text': question}
      ]; // Only text
    }

    final payload = {
      'model': modelId,
      'messages': [
        {'role': 'user', 'content': messageContent}
      ],
      'stream': true,
    };

    for (final key in params.keys) {
      // ignore params set to null
      // these may not have been initialized or set by the user yet
      if (params[key] == null) {
        continue;
      }

      payload[key] = params[key];
    }

    bool includeReasoning = params.containsKey("include_reasoning") &&
        params["include_reasoning"] == true;

    // Rest of the original stream handling remains the same
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
            if (data == '[DONE]') return;

            try {
              final dataObj = jsonDecode(data);
              final delta = dataObj['choices'][0]['delta'];

              // Handle content tokens
              if (delta.containsKey('content')) {
                final content = delta['content'];
                if (content != null) {
                  yield TokenEvent(TokenEventType.response, content);
                }
              }

              if (includeReasoning && delta.containsKey('reasoning')) {
                final reasoning = delta['reasoning'];
                if (reasoning != null) {
                  yield TokenEvent(TokenEventType.reasoning, reasoning);
                }
              }
            } catch (e) {
              // Ignore JSON decode errors
            }
          }
        }
      }
    }
  }
}
