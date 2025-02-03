import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../widgets/chat_message.dart';
import '../services/settings_service.dart';
import '../services/model_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'settings_screen.dart';
import '../models/llm_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final SettingsService _settingsService = SettingsService();
  late int _currentChatId;
  bool _isNewChat = true;
  LLMModel? _selectedModel;

  Future<List<Chat>> _loadChats() async {
    return await DatabaseHelper.instance.getChats();
  }

  Future<void> _sendToOpenRouter(String userMessage) async {
    final apiKey = await _settingsService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API key not configured in settings')),
      );
      return;
    }

    final siteUrl = await _settingsService.getSiteUrl() ?? '';
    final siteName = await _settingsService.getSiteName() ?? '';

    try {
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': siteUrl,
          'X-Title': siteName,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'openai/gpt-3.5-turbo',
          'messages': [
            {'role': 'user', 'content': userMessage}
          ],
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final aiResponse = responseBody['choices'][0]['message']['content'];

        final aiMessage = Message(
          id: 0,
          chatId: _currentChatId,
          text: aiResponse,
          isUser: false,
          createdAt: DateTime.now(),
        );
        await DatabaseHelper.instance.insertMessage(aiMessage);
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('API Error: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _createNewChat() async {
    if (_selectedModel == null) return;

    final newChat = Chat(
      id: 0,
      title: 'Chat with ${_selectedModel!.name}',
      modelId: _selectedModel!.id,
      createdAt: DateTime.now(),
    );

    _currentChatId = await DatabaseHelper.instance.insertChat(newChat);
    setState(() => _isNewChat = false);
  }

  void _handleSubmitted(String text) async {
    _textController.clear();

    if (_isNewChat) {
      await _createNewChat();
      _isNewChat = false;
    }

    final userMessage = Message(
      id: 0,
      chatId: _currentChatId,
      text: text,
      isUser: true,
      createdAt: DateTime.now(),
    );

    await DatabaseHelper.instance.insertMessage(userMessage);
    await _sendToOpenRouter(text);
    setState(() {});
  }

  Future<void> _showModelSelection() async {
    final models = await ModelService().getModels();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          child: StatefulBuilder(
            builder: (context, setState) {
              String searchQuery = '';

              return FutureBuilder<Set<String>>(
                future: _settingsService.getPinnedModels(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final pinnedModelIds = snapshot.data!;

                  final filteredPinned = models
                      .where((model) =>
                          pinnedModelIds.contains(model.id) &&
                          (model.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                              model.provider.toLowerCase().contains(searchQuery.toLowerCase()) ||
                              model.description.toLowerCase().contains(searchQuery.toLowerCase())))
                      .toList()
                    ..sort((a, b) => a.name.compareTo(b.name));

                  final filteredOthers = models
                      .where((model) =>
                          !pinnedModelIds.contains(model.id) &&
                          (model.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                              model.provider.toLowerCase().contains(searchQuery.toLowerCase()) ||
                              model.description.toLowerCase().contains(searchQuery.toLowerCase())))
                      .toList()
                    ..sort((a, b) => a.name.compareTo(b.name));

                  return Column(
                    children: [
                      AppBar(
                        title: const Text('Select Model'),
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () async {
                              Navigator.pop(context);
                              final newModels = await ModelService().getModels(forceRefresh: true);
                              _showModelSelection();
                            },
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Search models...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            setState(() => searchQuery = value);
                          },
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          children: [
                            if (filteredPinned.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                child: Text('Pinned Models', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              ...filteredPinned.map((model) => _buildModelTile(model, pinnedModelIds, setState)),
                            ],
                            if (filteredOthers.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                child: Text('All Models', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              ...filteredOthers.map((model) => _buildModelTile(model, pinnedModelIds, setState)),
                            ],
                            if (filteredPinned.isEmpty && filteredOthers.isEmpty)
                              const Center(child: Text('No models found')),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildModelTile(LLMModel model, Set<String> pinnedModelIds, StateSetter setState) {
    return ListTile(
      leading: CachedNetworkImage(
        imageUrl: model.iconUrl,
        width: 32,
        height: 32,
        placeholder: (context, url) => const CircularProgressIndicator(),
        errorWidget: (context, url, error) => const Icon(Icons.settings),
      ),
      title: Text(model.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(model.provider),
          Text(model.description, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              pinnedModelIds.contains(model.id) ? Icons.push_pin : Icons.push_pin_outlined,
              color: pinnedModelIds.contains(model.id) ? Colors.blue : null,
            ),
            onPressed: () async {
              if (pinnedModelIds.contains(model.id)) {
                await _settingsService.removePinnedModel(model.id);
              } else {
                await _settingsService.addPinnedModel(model.id);
              }
              setState(() {});
            },
          ),
          if (_selectedModel?.id == model.id) const Icon(Icons.check),
        ],
      ),
      onTap: () {
        setState(() => _selectedModel = model);
        Navigator.pop(context);
        _createNewChat();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chat Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: FutureBuilder<List<Chat>>(
          future: _loadChats(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            final chats = snapshot.data!;
            return Column(
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Chat',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('New Chat'),
                        onPressed: _showModelSelection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: chats.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: Text(chats[index].title),
                        subtitle: FutureBuilder<LLMModel?>(
                          future: _getModelForChat(chats[index].modelId),
                          builder: (context, snapshot) => Text(
                            snapshot.hasData
                              ? 'Model: ${snapshot.data!.name}'
                              : 'Unknown model',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _currentChatId = chats[index].id;
                            _isNewChat = false;
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: FutureBuilder<List<Message>>(
        future: _isNewChat ? Future.value([]) : DatabaseHelper.instance.getMessages(_currentChatId),
        builder: (context, snapshot) {
          final messages = snapshot.data ?? [];

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages.reversed.toList()[index];
                    return ChatMessage(
                      text: message.text,
                      isUser: message.isUser,
                    );
                  },
                ),
              ),
              _buildInput(),
            ],
          );
        },
      ),
    );
  }

  Future<LLMModel?> _getModelForChat(String modelId) async {
    final models = await ModelService().getModels();
    return models.firstWhere((m) => m.id == modelId);
  }


  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.grey[850],
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type your message...',
                hintStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20.0),
              ),
              onSubmitted: _handleSubmitted,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.blueGrey),
            onPressed: () => _handleSubmitted(_textController.text),
          ),
        ],
      ),
    );
  }
}
