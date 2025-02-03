import 'package:http/http.dart' as http;
import 'dart:convert';
import '../database/database_helper.dart';
import '../models/llm_model.dart';

class ModelService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<LLMModel>> getModels({bool forceRefresh = false}) async {
    final cachedModels = await _getCachedModels();
    if (cachedModels.isNotEmpty && !forceRefresh) {
      return cachedModels;
    }

    final response = await http.get(
      Uri.parse('https://openrouter.ai/api/v1/models'),
    );
    print ('Response: ${response.body}');

    if (response.statusCode == 200) {
      final models = (jsonDecode(response.body)['data'] as List)
          .map((e) => LLMModel.fromJson(e))
          .toList();
      await _dbHelper.cacheModels(models);
      return models;
    }

    return cachedModels; // Return cached if available
  }

  Future<List<LLMModel>> _getCachedModels() async {
    return await _dbHelper.getCachedModels();
  }
}
