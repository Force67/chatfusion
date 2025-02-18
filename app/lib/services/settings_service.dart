import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyApiKey = 'openrouter_api_key';
  static const _keySiteUrl = 'site_url';
  static const _keySiteName = 'site_name';

  Future<void> saveSettings({
    required String apiKey,
    required String siteUrl,
    required String siteName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiKey, apiKey);
    await prefs.setString(_keySiteUrl, siteUrl);
    await prefs.setString(_keySiteName, siteName);
  }

  Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyApiKey);
  }

  Future<String?> getSiteUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySiteUrl);
  }

  Future<String?> getSiteName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySiteName);
  }

  Future<Set<String>> getPinnedModels() async {
    final prefs = await SharedPreferences.getInstance();
    return Set.from(prefs.getStringList('pinnedModels') ?? []);
  }

  Future<void> addPinnedModel(String modelId) async {
    final prefs = await SharedPreferences.getInstance();
    final pinned = await getPinnedModels();
    pinned.add(modelId);
    await prefs.setStringList('pinnedModels', pinned.toList());
  }

  Future<void> removePinnedModel(String modelId) async {
    final prefs = await SharedPreferences.getInstance();
    final pinned = await getPinnedModels();
    pinned.remove(modelId);
    await prefs.setStringList('pinnedModels', pinned.toList());
  }
}
