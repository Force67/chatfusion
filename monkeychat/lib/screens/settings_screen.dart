import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../database/database_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();
  final _siteUrlController = TextEditingController();
  final _siteNameController = TextEditingController();
  final _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _apiKeyController.text = await _settingsService.getApiKey() ?? '';
    _siteUrlController.text = await _settingsService.getSiteUrl() ?? '';
    _siteNameController.text = await _settingsService.getSiteName() ?? '';
    setState(() {});
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      await _settingsService.saveSettings(
        apiKey: _apiKeyController.text,
        siteUrl: _siteUrlController.text,
        siteName: _siteNameController.text,
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'OpenRouter API Key',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your API key';
                  }
                  return null;
                },
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _siteUrlController,
                decoration: const InputDecoration(
                  labelText: 'Site URL (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _siteNameController,
                decoration: const InputDecoration(
                  labelText: 'Site Name (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveSettings,
                child: const Text('Save Settings'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                child: const Text('Erase Settings'),
                onPressed: () async {
                  await _settingsService.saveSettings(
                    apiKey: '',
                    siteUrl: '',
                    siteName: '',
                  );
                  await _loadSettings();
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                child: const Text('Erase Database'),
                onPressed: () async {
                  await DatabaseHelper.instance.clearAll();
                  await DatabaseHelper.instance.getChats();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
