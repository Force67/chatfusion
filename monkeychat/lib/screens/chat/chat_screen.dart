import 'package:flutter/material.dart';
import 'dart:async';

import 'package:monkeychat/screens/settings/settings_screen.dart';
import 'package:monkeychat/screens/settings/settings_cubit.dart';

import 'package:monkeychat/services/ai_provider.dart';
import 'package:monkeychat/database/local_db.dart';
import 'package:monkeychat/models/chat.dart';
import 'package:monkeychat/models/message.dart';
import 'package:monkeychat/widgets/chat_message.dart';
import 'package:monkeychat/services/settings_service.dart';
import 'package:monkeychat/services/ai_provider_or.dart';
import 'package:monkeychat/models/llm.dart';
import 'package:monkeychat/widgets/model_selection_dialog.dart';
import 'package:monkeychat/widgets/chat_list_sidebar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:monkeychat/widgets/model_settings_sidebar.dart';

import 'chat_cubit.dart';
import 'chat_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _isSettingsSidebarOpen = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _showModelSelection(BuildContext context, ChatCubit cubit) async {
    showDialog(
      context: context,
      builder: (context) => ModelSelectionDialog(
        settingsService: SettingsService(),
        modelService: AIProviderOpenrouter(),
        onModelSelected: (model) {
          cubit.selectModel(model);
          cubit.createNewChat();
        },
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, ChatState state) {
    return FutureBuilder<List<Message>>(
      future: state.isNewChat
          ? Future.value([])
          : DatabaseHelper.instance.getMessages(state.currentChatId),
      builder: (context, snapshot) {
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
                  messages.length + (state.isResponding ? 1 : 0), // Modified line
                  itemBuilder: (context, index) {
                    // Streaming message
                    if (state.isResponding && index == 0) {
                      // Modified condition
                      return ChatMessage(
                        text: state.streamedResponse,
                        isUser: false,
                        isStreaming: true,
                        reasoning: state.streamedReasoning,
                      );
                    }

                    // Adjust index for finalized messages
                    final messageIndex = state.isResponding ? index - 1 : index;
                    final message = messages.reversed.toList()[messageIndex];

                    return ChatMessage(
                      text: message.text,
                      reasoning: message.reasoning,
                      isUser: message.isUser,
                      isStreaming: false,
                      onRetry: () => context.read<ChatCubit>().retryMessage(message),
                    );
                  },
                ),
              ),
              _Input(textController: _textController),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChatCubit(),
      child: BlocConsumer<ChatCubit, ChatState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }

          if (state.chatsDeleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('All chats deleted successfully')),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Monkeychat'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => BlocProvider(
                      create: (context) => SettingsCubit(),
                     child: SettingsScreen(),
                    ),
                  ),
                ),
                ),
              ],
            ),
            drawer: Drawer(
              child: ChatListSidebar(
                currentChatId: state.currentChatId,
                onChatSelected: (chatId) async {
                  final chat = await DatabaseHelper.instance.getChat(chatId);
                  final model = await context.read<ChatCubit>().getModelForChat(chat.modelId);
                  if (model != null) {
                    context.read<ChatCubit>().initChat(chatId, model, chat.modelSettings ?? {});
                  }
                },
                onNewChat: () => _showModelSelection(context, context.read<ChatCubit>()),
                onDeleteAllChats: () => context.read<ChatCubit>().deleteAllChats(),
                getModelForChat: context.read<ChatCubit>().getModelForChat,
              ),
            ),
            body: Stack(
              children: [
                // Main content area
                _buildMainContent(context, state),

                // Right sidebar overlay
                if (_isSettingsSidebarOpen) ...[
                  GestureDetector(
                    onTap: () => setState(() => _isSettingsSidebarOpen = false),
                    child: Container(color: Colors.black54),
                  ),
                  ModelSettingsSidebar(
                    model: state.selectedModel,
                    parameters: state.modelSettings,
                    onParametersChanged: (newParams) =>
                        context.read<ChatCubit>().updateModelSettings(newParams),
                    onDismissed: () => setState(() => _isSettingsSidebarOpen = false),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({
    Key? key,
    required TextEditingController textController,
  }) : _textController = textController, super(key: key);

  final TextEditingController _textController;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatCubit, ChatState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          color: Colors.grey[850],
          child: Column(
            children: [
              if (state.selectedImagePath != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.image, color: Colors.blueGrey, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Attached: ${state.selectedImagePath!.split('/').last}',
                          style: const TextStyle(color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            size: 18, color: Colors.blueGrey),
                        onPressed: () =>  context.read<ChatCubit>().sendMessage("", null),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.clear_all, color: Colors.blueGrey),
                    tooltip: "Clear context",
                    onPressed: () => context.read<ChatCubit>().clearContext(),
                  ),
                  // Add the media selector button here
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.blueGrey),
                    tooltip: 'Attach file',
                    onPressed: () async {
                      if (state.selectedModel == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please select a model first')),
                        );
                        return;
                      }

                      final FileType fileType = state.selectedModel!.supportsImageInput
                          ? FileType.image
                          : FileType.custom;

                      final List<String>? allowedExtensions =
                          state.selectedModel!.supportsImageInput
                              ? null
                              : ['txt', 'text'];

                      context.read<ChatCubit>().attachFile(fileType,allowedExtensions);
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
                      onSubmitted: (text) => context.read<ChatCubit>().sendMessage(text, state.selectedImagePath),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      state.isStreaming ? Icons.stop : Icons.send,
                      color: state.isStreaming ? Colors.red : Colors.blueGrey,
                    ),
                    tooltip: state.isStreaming ? "Stop generating" : "Send message",
                    onPressed: state.isStreaming
                        ? () => context.read<ChatCubit>().stopGenerating()
                        : () =>  context.read<ChatCubit>().sendMessage(_textController.text, state.selectedImagePath),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
