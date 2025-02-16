import 'package:flutter/material.dart';
import 'dart:async';
import 'package:monkeychat/services/ai_provider.dart';
import '../database/local_db.dart';
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
import '../widgets/model_settings_sidebar.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final AIProvider _provider = AIProviderOpenrouter();
  int _currentChatId = 0;
  bool _isNewChat = true;
  LLModel? _selectedModel;

  String _streamedResponse = '';
  String _streamedReasoning = '';

  bool _contextCleared = false;
  String? _selectedImagePath;

  bool _isResponding = false;
  bool _isStreaming = false;
  StreamSubscription? _responseStreamSubscription;

  bool _isSettingsSidebarOpen = false;
  Map<String, dynamic> _modelSettings = {};

  Future<void> _sendToProvider(
    Message userMessage, {
    bool insertUserMessage = true,
    List<String>? contextMessages,
    String? imagePath,
  }) async {
    if (_selectedModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a model first')),
      );
      return;
    }

    if (insertUserMessage) {
      await DatabaseHelper.instance.insertMessage(userMessage);
    }

    setState(() {
      _streamedResponse = '';
      _streamedReasoning = '';
      _isResponding = true;
      _isStreaming = true;
    });

    try {
      // Use provided context or fetch fresh messages
      final List<String> finalContext = contextMessages ??
        (await DatabaseHelper.instance.getMessages(_currentChatId))
          .where((m) => m.id <= userMessage.id) // Only messages up to target user message
          .map((m) => m.text)
          .toList();

      // If context was cleared, only use the latest user message
      final processedContext = _contextCleared
          ? [userMessage.text]
          : finalContext;

      final stream = _provider.streamResponse(
        _selectedModel!.id,
        processedContext.join('\n'),
        _modelSettings,
        imagePath: imagePath,
      );

      _responseStreamSubscription = stream.listen((chunk) {
        setState(() {
          if (chunk.type == TokenEventType.response) {
            _streamedResponse += chunk.text;
          } else if (chunk.type == TokenEventType.reasoning) {
            _streamedReasoning += chunk.text;
          }
        });
      }, onDone: () async {
        final aiMessage = Message(
          id: 0,
          chatId: _currentChatId,
          text: _streamedResponse,
          reasoning: _streamedReasoning,
          isUser: false,
          createdAt: DateTime.now(),
        );

        await DatabaseHelper.instance.insertMessage(aiMessage);
        setState(() {
          _isResponding = false;
          _isStreaming = false;
        });
      }, onError: (e) {
        setState(() {
          _isResponding = false;
          _isStreaming = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _stopGenerating() {
    _responseStreamSubscription?.cancel();
    setState(() {
      _isResponding = false;
      _isStreaming = false;
    });
  }

  static dynamic _findDefaultValueForParam(String name) {
    switch (name) {
      case 'temperature':
        return 1.0;
      case 'top_p':
        return 1.0;
      case 'top_k':
        return 0;
      case 'frequency_penalty':
        return 0.0;
      case 'presence_penalty':
        return 0.0;
      case 'repetition_penalty':
        return 1.0;
      case 'min_p':
        return 0.0;
      case 'top_a':
        return 0.0;
      case 'include_reasoning':
        return true;
      default:
        return null; // Return null for parameters without a specified default
    }
  }

  Future<void> _createNewChat() async {
    if (_selectedModel == null) return;

    // Initialize the model settings with the default values
    // But only for parameters that are actually available to modify (as provided by the API)
    // The default values
    for (var settingName in _selectedModel!.tunableParameters) {
      _modelSettings[settingName] = _findDefaultValueForParam(settingName);
    }

    final newChat = Chat(
      id: 0,
      title: 'Chat with ${_selectedModel!.name}',
      modelId: _selectedModel!.id,
      createdAt: DateTime.now(),
      modelSettings: _modelSettings,
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

    // Create temporary message with placeholder ID
    final userMessage = Message(
      id: -1, // Temporary invalid ID
      chatId: _currentChatId,
      text: text,
      reasoning: "",
      isUser: true,
      createdAt: DateTime.now(),
    );

    try {
      // Insert message and get actual database ID
      final insertedId = await DatabaseHelper.instance.insertMessage(userMessage);
      final validMessage = userMessage.copyWith(id: insertedId);

      await _sendToProvider(
        validMessage,
        imagePath: _selectedImagePath,
        insertUserMessage: false, // Already inserted
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    } finally {
      setState(() => _selectedImagePath = null);
    }
  }


  Future<void> _retryMessage(Message messageToRetry) async {
    final messages = await DatabaseHelper.instance.getMessages(_currentChatId);

    // Find the user message that triggered this AI response
    final userMessageIndex = messages.indexWhere(
      (m) => m.id == messageToRetry.id - 1 && m.isUser
    );

    if (userMessageIndex == -1) return;

    // Delete ONLY the target AI message
    await DatabaseHelper.instance.deleteMessage(messageToRetry.id);

    // Get messages up to (and including) the original user message
    final contextMessages = messages
      .sublist(0, userMessageIndex + 1)
      .map((m) => m.text)
      .toList();

    // Regenerate with original context
    await _sendToProvider(
      messages[userMessageIndex],
      insertUserMessage: false,
      contextMessages: contextMessages,
    );
  }

  Future<void> _showModelSelection() async {
    showDialog(
      context: context,
      builder: (context) => ModelSelectionDialog(
        settingsService: SettingsService(),
        modelService: AIProviderOpenrouter(),
        onModelSelected: (model) {
          setState(() {
            _selectedModel = model;
            _modelSettings = {}; // Reset settings for new model
          });
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

  // Update the ListView.builder in _buildMainContent
  Widget _buildMainContent(AsyncSnapshot<List<Message>> snapshot) {
    final messages = snapshot.data ?? [];

    return GestureDetector(
      onHorizontalDragStart: (details) {
        if (details.globalPosition.dx >
            MediaQuery.of(context).size.width - 20) {
          setState(() => _isSettingsSidebarOpen = true);
        }
      },
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount:
                  messages.length + (_isResponding ? 1 : 0), // Modified line
              itemBuilder: (context, index) {
                // Streaming message
                if (_isResponding && index == 0) {
                  // Modified condition
                  return ChatMessage(
                    text: _streamedResponse,
                    isUser: false,
                    isStreaming: true,
                    reasoning: _streamedReasoning,
                  );
                }

                // Adjust index for finalized messages
                final messageIndex = _isResponding ? index - 1 : index;
                final message = messages.reversed.toList()[messageIndex];

                return ChatMessage(
                  text: message.text,
                  reasoning: message.reasoning,
                  isUser: message.isUser,
                  isStreaming: false,
                  onRetry: () => _retryMessage(message),
                );
              },
            ),
          ),
          _buildInput(),
        ],
      ),
    );
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
          onChatSelected: (chatId) async {
            final chat = await DatabaseHelper.instance.getChat(chatId);
            final model = await _getModelForChat(chat.modelId);

            setState(() {
              _currentChatId = chatId;
              _isNewChat = false;
              _selectedModel = model;
              _modelSettings = chat.modelSettings ?? {};
            });
            Navigator.pop(context);
          },
          onNewChat: _showModelSelection,
          onDeleteAllChats: _deleteAllChats,
          getModelForChat: _getModelForChat,
        ),
      ),
      body: Stack(
        children: [
          // Main content area
          FutureBuilder<List<Message>>(
            future: _isNewChat
                ? Future.value([])
                : DatabaseHelper.instance.getMessages(_currentChatId),
            builder: (context, snapshot) {
              return _buildMainContent(snapshot);
            },
          ),

          // Right sidebar overlay
          if (_isSettingsSidebarOpen) ...[
            GestureDetector(
              onTap: () => setState(() => _isSettingsSidebarOpen = false),
              child: Container(color: Colors.black54),
            ),
            ModelSettingsSidebar(
              model: _selectedModel,
              parameters: _modelSettings,
              onParametersChanged: (newParams) =>
                  setState(() => _modelSettings = newParams),
              onDismissed: () => setState(() => _isSettingsSidebarOpen = false),
            ),
          ],
        ],
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
                    icon: const Icon(Icons.close,
                        size: 18, color: Colors.blueGrey),
                    onPressed: () => setState(() => _selectedImagePath = null),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.clear_all, color: Colors.blueGrey),
                tooltip: "Clear context",
                onPressed: _clearContext,
              ),
              // Add the media selector button here
              IconButton(
                icon: const Icon(Icons.attach_file, color: Colors.blueGrey),
                tooltip: 'Attach file',
                onPressed: () async {
                  if (_selectedModel == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please select a model first')),
                    );
                    return;
                  }

                  final FileType fileType = _selectedModel!.supportsImageInput
                      ? FileType.image
                      : FileType.custom;

                  final List<String>? allowedExtensions =
                      _selectedModel!.supportsImageInput
                          ? null
                          : ['txt', 'text'];

                  try {
                    final FilePickerResult? result =
                        await FilePicker.platform.pickFiles(
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
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20.0),
                  ),
                  onSubmitted: _handleSubmitted,
                ),
              ),
              IconButton(
                icon: Icon(
                  _isStreaming ? Icons.stop : Icons.send,
                  color: _isStreaming ? Colors.red : Colors.blueGrey,
                ),
                tooltip: _isStreaming ? "Stop generating" : "Send message",
                onPressed: _isStreaming
                    ? _stopGenerating
                    : () => _handleSubmitted(_textController.text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
