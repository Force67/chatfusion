import 'package:flutter/material.dart';
import 'package:chatfusion/models/folder.dart';
import 'dart:async';
import 'dart:io'; // Import for File

import 'package:chatfusion/screens/settings/settings_screen.dart';
import 'package:chatfusion/screens/settings/settings_cubit.dart';

import 'package:chatfusion/database/local_db.dart';

import 'package:chatfusion/models/message.dart';
import 'package:chatfusion/services/model_service.dart';
import 'package:chatfusion/widgets/chat_message.dart';
import 'package:chatfusion/services/settings_service.dart';
import 'package:chatfusion/services/ai_provider_or.dart';
import 'package:chatfusion/widgets/model_selection_dialog.dart';
import 'package:chatfusion/widgets/chat_list_sidebar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:chatfusion/widgets/model_settings_sidebar.dart';

import 'chat_cubit.dart';
import 'chat_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

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

  Future<void> _showModelSelection(
      BuildContext context, ChatCubit cubit, Folder folderId) async {
    showDialog(
      context: context,
      builder: (context) => ModelSelectionDialog(
        settingsService: SettingsService(),
        modelService: AIProviderOpenrouter(),
        onModelSelected: (model) {
          cubit.selectModel(model);
          cubit.createNewChat(folderId);
        },
      ),
    );
  }

  Widget _buildSystemMessage(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontStyle: FontStyle.italic,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, ChatState state) {
    return FutureBuilder<List<Message>>(
      future: state.isNewChat
          ? Future.value([])
          : LocalDb.instance.messages.then((messagesCollection) =>
              messagesCollection.getMessages(state.currentChatId)),
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
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ListView.builder(
                      reverse: true,
                      itemCount: messages.length + (state.isResponding ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Adjustments for streaming message
                        if (state.isResponding && index == 0) {
                          return ChatMessage(
                            text: state.streamedResponse,
                            isUser: false,
                            isStreaming: true,
                            reasoning: state.streamedReasoning,
                          );
                        }

                        final messageIndex =
                            state.isResponding ? index - 1 : index;
                        final message =
                            messages.reversed.toList()[messageIndex];

                        // Render differently based on message type
                        if (message.isSystem()) {
                          return _buildSystemMessage(
                              message.text); //call new build system message
                        } else {
                          return ChatMessage(
                            text: message.text,
                            reasoning: message.reasoning,
                            isUser: message.isUser(),
                            isStreaming: false,
                            attachments: message.attachments,
                            onRetry: () =>
                                context.read<ChatCubit>().retryMessage(message),
                          );
                        }
                      },
                    ),
                    // Add loading animation when isThinking is true and no messages or is a new chat
                    if (state.isThinking &&
                        (messages.isEmpty || state.isNewChat))
                      LoadingAnimationWidget.discreteCircle(
                        color: Colors.blue,
                        size: 40,
                      ),
                  ],
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
    final modelSVC = context.read<ModelService>();
    return BlocProvider(
      create: (context) => ChatCubit(modelSVC),
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
              title: const Text('ChatFusion'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BlocProvider(
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
                  if (!mounted) return;
                  final chats = await LocalDb.instance.chats;
                  final chat = await chats.getChat(chatId);
                  final model = await context
                      .read<ChatCubit>()
                      .getModelForChat(chat.modelId);
                  if (model != null && context.mounted) {
                    context
                        .read<ChatCubit>()
                        .initChat(chatId, model, chat.modelSettings);
                  }
                },
                onNewChat: (folderId) async {
                  _showModelSelection(
                      context, context.read<ChatCubit>(), folderId);
                },
                onDeleteAllChats: () =>
                    context.read<ChatCubit>().deleteAllChats(),
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
                    onParametersChanged: (newParams) => context
                        .read<ChatCubit>()
                        .updateModelSettings(newParams),
                    onDismissed: () =>
                        setState(() => _isSettingsSidebarOpen = false),
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
    required TextEditingController textController,
  }) : _textController = textController;

  final TextEditingController _textController;
  final int maxAttachments = 4; // Defining the maximum number of files.

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatCubit, ChatState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          color: Colors.grey[850],
          child: Column(
            children: [
              if (state.selectedAttachmentPaths.isNotEmpty)
                SizedBox(
                  height: 60, // Adjust as needed
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: state.selectedAttachmentPaths.length,
                    itemBuilder: (context, index) {
                      final imagePath = state.selectedAttachmentPaths[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Stack(
                          children: [
                            // Conditionally render an image preview
                            if (imagePath.isNotEmpty &&
                                [
                                  'jpg',
                                  'jpeg',
                                  'png',
                                  'gif',
                                  'bmp'
                                ].any((ext) =>
                                    imagePath.toLowerCase().endsWith('.$ext')))
                              Image.file(
                                File(imagePath),
                                width: 50, // Adjust size
                                height: 50,
                                fit: BoxFit.cover,
                              )
                            else
                              const Icon(
                                  Icons.insert_drive_file, // Generic file icon
                                  color: Colors.blueGrey,
                                  size: 50),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: InkWell(
                                onTap: () {
                                  context.read<ChatCubit>().removeAttachment(
                                      imagePath); // Call function to remove the path
                                },
                                child: const Icon(Icons.cancel,
                                    color: Colors.red, size: 16),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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

                      if (state.selectedAttachmentPaths.length >=
                          maxAttachments) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'You can only attach a maximum of $maxAttachments files.')),
                        );
                        return;
                      }

                      final FileType fileType =
                          state.selectedModel!.capabilities.supportsImageInput
                              ? FileType.image
                              : FileType.any; // Allow any file type

                      final List<String>? allowedExtensions =
                          state.selectedModel!.capabilities.supportsImageInput
                              ? null
                              : null; //Allow any extension

                      context.read<ChatCubit>().attachFiles(
                          fileType, allowedExtensions,
                          maxAttachments:
                              maxAttachments); // Changed to attachFiles
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 30,
                      minLines: 1,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: const TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20.0),
                      ),
                      onSubmitted: (text) => {
                        context.read<ChatCubit>().sendMessage(text,
                            state.selectedAttachmentPaths), //send the list
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      state.isStreaming ? Icons.stop : Icons.send,
                      color: state.isStreaming ? Colors.red : Colors.blueGrey,
                    ),
                    tooltip:
                        state.isStreaming ? "Stop generating" : "Send message",
                    onPressed: state.isStreaming
                        ? () => context.read<ChatCubit>().stopGenerating()
                        : () => {
                              context.read<ChatCubit>().sendMessage(
                                  _textController.text,
                                  state.selectedAttachmentPaths),
                              _textController.clear()
                            }
                    //send the list
                    ,
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
