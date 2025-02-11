// ../screens/chat_settings_screen.dart

import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../database/database_helper.dart';

class ChatSettingsScreen extends StatefulWidget {
  final Chat chat;

  const ChatSettingsScreen({Key? key, required this.chat}) : super(key: key);

  @override
  _ChatSettingsScreenState createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  late double _temperature;
  late int _maxTokens;
  late double _topP;
  late double _frequencyPenalty;
  late double _presencePenalty;

  @override
  void initState() {
    super.initState();
    _temperature = widget.chat.temperature;
    _maxTokens = widget.chat.maxTokens;
    _topP = widget.chat.topP;
    _frequencyPenalty = widget.chat.frequencyPenalty;
    _presencePenalty = widget.chat.presencePenalty;
  }

  Future<void> _saveSettings() async {
    final updatedChat = widget.chat.copyWith(
      temperature: _temperature,
      maxTokens: _maxTokens,
      topP: _topP,
      frequencyPenalty: _frequencyPenalty,
      presencePenalty: _presencePenalty,
    );

    await DatabaseHelper.instance.updateChatSettings(updatedChat);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat settings saved')),
    );

    Navigator.pop(context, updatedChat);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Temperature Slider
            Text('Temperature: ${_temperature.toStringAsFixed(2)}'),
            Slider(
              value: _temperature,
              min: 0.0,
              max: 2.0,
              divisions: 20,
              label: _temperature.toStringAsFixed(2),
              onChanged: (value) {
                setState(() {
                  _temperature = value;
                });
              },
            ),
            const SizedBox(height: 20),

            // Max Tokens Slider
            Text('Max Tokens: $_maxTokens'),
            Slider(
              value: _maxTokens.toDouble(),
              min: 1,
              max: 4096,
              divisions: 4095,
              label: '$_maxTokens',
              onChanged: (value) {
                setState(() {
                  _maxTokens = value.toInt();
                });
              },
            ),
            const SizedBox(height: 20),

            // Top P Slider
            Text('Top P: ${_topP.toStringAsFixed(2)}'),
            Slider(
              value: _topP,
              min: 0.0,
              max: 1.0,
              divisions: 100,
              label: _topP.toStringAsFixed(2),
              onChanged: (value) {
                setState(() {
                  _topP = value;
                });
              },
            ),
            const SizedBox(height: 20),

            // Frequency Penalty Slider
            Text('Frequency Penalty: ${_frequencyPenalty.toStringAsFixed(2)}'),
            Slider(
              value: _frequencyPenalty,
              min: -2.0,
              max: 2.0,
              divisions: 40,
              label: _frequencyPenalty.toStringAsFixed(2),
              onChanged: (value) {
                setState(() {
                  _frequencyPenalty = value;
                });
              },
            ),
            const SizedBox(height: 20),

            // Presence Penalty Slider
            Text('Presence Penalty: ${_presencePenalty.toStringAsFixed(2)}'),
            Slider(
              value: _presencePenalty,
              min: -2.0,
              max: 2.0,
              divisions: 40,
              label: _presencePenalty.toStringAsFixed(2),
              onChanged: (value) {
                setState(() {
                  _presencePenalty = value;
                });
              },
            ),
            const SizedBox(height: 20),

            // Additional Parameters can be added here similarly
          ],
        ),
      ),
    );
  }
}
