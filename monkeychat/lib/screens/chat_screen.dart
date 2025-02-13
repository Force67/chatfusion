import 'package:flutter/material.dart';
import 'package:monkeychat/services/ai_provider.dart';
import '../database/database_helper.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../widgets/chat_message.dart';
import '../services/settings_service.dart';
import '../services/ai_provider_or.dart';
import 'settings_screen.dart';
import '../models/llm.dart';
import '../widgets/model_selection_dialog.dart';
import '../widgets/chat_list_sidebar.dart';
import 'package:file_picker/file_picker.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final AIProvider _provider = AIProviderOpenrouter();
  int _currentChatId = 0;
  bool _isNewChat = true;
  LLModel? _selectedModel;
  String _streamedResponse = '';
  bool _contextCleared = false;
  String? _selectedImagePath;

  Future<List<Chat>> _loadChats() async {
    return await DatabaseHelper.instance.getChats();
  }

  Future<void> _sendToProvider(String userMessage, {String? imagePath}) async {
    if (_selectedModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a model first')),
      );
      return;
    }

    final userMessageObj = Message(
      id: 0,
      chatId: _currentChatId,
      text: userMessage,
      isUser: true,
      createdAt: DateTime.now(),
    );

    await DatabaseHelper.instance.insertMessage(userMessageObj);

    setState(() {
      _streamedResponse = ''; // Reset the streamed response
    });

    try {
      final messages =
          await DatabaseHelper.instance.getMessages(_currentChatId);
      final contextMessages =
          _contextCleared ? [userMessage] : messages.map((m) => m.text).toList()
            ..add(userMessage);

      final stream = _provider.streamResponse(
          _selectedModel!.id, contextMessages.join('\n'), imagePath: _selectedImagePath);

      await for (final chunk in stream) {
        setState(() {
          _streamedResponse += chunk; // Append the chunk to the response
        });
      }

      final aiMessage = Message(
        id: 0,
        chatId: _currentChatId,
        text: _streamedResponse,
        isUser: false,
        createdAt: DateTime.now(),
      );

      await DatabaseHelper.instance.insertMessage(aiMessage);

      setState(() {
        _streamedResponse = '';
      });
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

  Future<void> _deleteAllChats() async {
    try {
      await DatabaseHelper.instance.clearChats();
      setState(() {}); // Refresh the UI
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All chats deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete chats: $e')),
      );
    }
  }

  void _handleSubmitted(String text) async {
    if (text.trim().isEmpty && _selectedImagePath == null) return;
    _textController.clear();
    await _sendToProvider(text, imagePath: _selectedImagePath);
    setState(() {
      _selectedImagePath = null; // Reset after sending
    });
  }

  Future<void> _showModelSelection() async {
    showDialog(
      context: context,
      builder: (context) => ModelSelectionDialog(
        settingsService: SettingsService(),
        modelService: AIProviderOpenrouter(),
        onModelSelected: (model) {
          setState(() => _selectedModel = model);
          _createNewChat();
        },
      ),
    );
  }

  void _clearContext() {
    setState(() {
      _contextCleared = true;
    });
  }

  Future<LLModel?> _getModelForChat(String modelId) async {
    final models = await _provider.getModels();
    return models.firstWhere((m) => m.id == modelId);
  }

  @override
  Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Monkeychat'),
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
          child: ChatListSidebar(
            currentChatId: _currentChatId,
            onChatSelected: (chatId) {
              setState(() {
                _currentChatId = chatId;
                _isNewChat = false;
              });
              Navigator.pop(context);
            },
            onNewChat: _showModelSelection,
            onDeleteAllChats: _deleteAllChats,
            getModelForChat: _getModelForChat,
          ),
        ),
      body: FutureBuilder<List<Message>>(
        future: _isNewChat
            ? Future.value([])
            : DatabaseHelper.instance.getMessages(_currentChatId),
        builder: (context, snapshot) {
          final messages = snapshot.data ?? [];

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12.0),
                  itemCount:
                      messages.length + (_streamedResponse.isNotEmpty ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_streamedResponse.isNotEmpty && index == 0) {
                      return ChatMessage(
                        text: _streamedResponse,
                        isUser: false,
                        isStreaming: true,
                      );
                    }
                    final message = messages.reversed.toList()[
                        _streamedResponse.isNotEmpty ? index - 1 : index];
                    return Column(
                      children: [
                        if (_contextCleared && index == messages.length - 1)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'Context Cleared',
                              style: TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ChatMessage(
                          text: message.text,
                          isUser: message.isUser,
                          isStreaming: false,
                        ),
                      ],
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

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.grey[850],
      child: Column(
            children: [
              if (_selectedImagePath != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.image, color: Colors.blueGrey, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Attached: ${_selectedImagePath!.split('/').last}',
                          style: const TextStyle(color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.blueGrey),
                        onPressed: () => setState(() => _selectedImagePath = null),
                      ),
                    ],
                  ),
                ),
                Row(
        children: [
          IconButton(
            icon: const Icon(Icons.clear_all, color: Colors.blueGrey),
            onPressed: _clearContext,
          ),
          // Add the media selector button here
          IconButton(
            icon: const Icon(Icons.attach_file, color: Colors.blueGrey),
            tooltip: 'Attach file',
            onPressed: () async {
              if (_selectedModel == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a model first')),
                );
                return;
              }

              final FileType fileType = _selectedModel!.supportsImageInput
                  ? FileType.image
                  : FileType.custom;

              final List<String>? allowedExtensions = _selectedModel!.supportsImageInput
                  ? null
                  : ['txt', 'text'];

              try {
                final FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: fileType,
                  allowedExtensions: allowedExtensions,
                );

                if (result != null && result.files.isNotEmpty) {
                  final PlatformFile file = result.files.first;
                  if (_selectedModel!.supportsImageInput) {
                    setState(() {
                      _selectedImagePath = file.path;
                    });
                  } else {
                    // Handle text file selection logic
                  }
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error selecting file: $e')),
                );
              }
            },
          ),
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
            ],
      ),
    );
  }
}
