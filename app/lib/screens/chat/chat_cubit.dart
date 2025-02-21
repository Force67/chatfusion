// chat_cubit.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:monkeychat/database/local_db.dart';
import 'package:monkeychat/models/chat.dart';
import 'package:monkeychat/models/folder.dart';
import 'package:monkeychat/models/message.dart';
import 'package:monkeychat/services/ai_provider.dart';
import 'package:monkeychat/models/llm.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import "chat_state.dart";

import "package:monkeychat/services/ai_provider_or.dart";

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class ChatCubit extends Cubit<ChatState> {
  final AIProvider provider = AIProviderOpenrouter();

  ChatCubit()
      : super(ChatState(
          selectedAttachmentPaths: [],
          selectedModel: null,
          modelSettings: {},
          isThinking: false, // Initialize isThinking to false
        )) {
    _loadLastChat();
  }

  Future<void> initChat(int chatId, LLModel selectedModel,
      Map<String, dynamic> modelSettings) async {
    emit(state.copyWith(
      currentChatId: chatId,
      isNewChat: false,
      selectedModel: selectedModel,
      modelSettings: modelSettings,
      selectedAttachmentPaths: [],
      isThinking: false, // Stop thinking when chat is initialized
    ));
  }

  Future<void> _loadLastChat() async {
    emit(state.copyWith(isThinking: true)); // Start thinking

    try {
      final chatsCollection = await LocalDb.instance.chats;
      final lastChat = await chatsCollection.getLastChat();
      if (lastChat != null) {
        final model = await getModelForChat(lastChat.modelId);
        if (model != null) {
          await initChat(
            lastChat.id,
            model,
            lastChat.modelSettings ?? {},
          );
        } else {
          emit(state.copyWith(isThinking: false));
        }
      } else {
        emit(state.copyWith(isThinking: false)); // Stop thinking
      }
    } catch (e) {
      emit(state.copyWith(
          errorMessage: 'Failed to load last chat: $e',
          isThinking: false)); // Stop thinking on error
    }
  }

  void selectModel(LLModel model) {
    emit(state.copyWith(selectedModel: model, modelSettings: {}));
  }

  // Helper function to compare new and old settings and format the output.
  String _formatSettingsChanges(
      Map<String, dynamic> oldParams, Map<String, dynamic> newParams) {
    List<String> changes = [];

    // List of parameter keys we want to display (customize this). Make sure it matches the models keys
    const displayKeys = [
      'temperature',
      'max_tokens',
      'top_p'
    ]; // Add all appropriate keys

    for (final key in displayKeys) {
      final oldValue = oldParams[key];
      final newValue = newParams[key];
      //check both null or both not null, if both null its ok and there is no change, same with not null both values should be the same
      if ((oldValue == null && newValue != null) ||
          (oldValue != null && newValue == null) ||
          (oldValue != newValue)) {
        changes.add(
            "${_formatKeyName(key)} changed to: ${newValue ?? 'default'}"); // Use a helper to format key name
      }
    }

    return changes.join(", ");
  }

  // Helper function to make key names more readable.
  String _formatKeyName(String key) {
    switch (key) {
      case 'temperature':
        return 'Temperature';
      case 'max_tokens':
        return 'Max Tokens';
      case 'top_p':
        return 'Top P';
      // add all necessary cases
      default:
        return key.replaceAll('_', ' ').capitalize(); // general fallback
    }
  }

  Future<void> updateModelSettings(Map<String, dynamic> newParams) async {
    final currentModel = state.selectedModel;

    if (currentModel == null) {
      return;
    }

    // Format the settings and their values into a human-readable string.
    String settingsChanges =
        _formatSettingsChanges(state.modelSettings, newParams);

    // If no settings were actually changed, don't add a message.
    if (settingsChanges.isEmpty) {
      return; // early exist
    }

    //Emit Thinking
    emit(state.copyWith(isThinking: true));

    // Create and add the system message.
    await _addSystemMessage("Params updated: $settingsChanges");

    // Persist/update the new settings
    final chats = await LocalDb.instance.chats;
    final chatId = state.currentChatId;

    chats.updateParams(chatId, newParams);
    emit(state.copyWith(modelSettings: newParams, isThinking: false));
  }

  Future<void> _addSystemMessage(String messageText) async {
    final chatId = state.currentChatId;

    final message = Message(
        id: DateTime.now().millisecondsSinceEpoch,
        chatId: chatId,
        type: MessageType.system,
        text: messageText,
        reasoning: "",
        attachments: [],
        createdAt: DateTime.now());

    final localDb = LocalDb.instance;
    final messageCollection = await localDb.messages;
    await messageCollection.insertMessage(message);

    emit(state.copyWith()); // trigger rebuild so the ui picks up the change
  }

  // Modify sendMessage to handle File objects
  Future<void> sendMessage(String text, List<String> attachmentPaths) async {
    if (state.selectedModel == null) {
      emit(state.copyWith(errorMessage: 'Please select a model first'));
      return;
    }

    if (text.trim().isEmpty) return;

    emit(state.copyWith(isThinking: true)); // Start thinking BEFORE sending

    List<File> attachmentFiles = [];
    // Create File objects from the selected paths
    for (final path in attachmentPaths) {
      attachmentFiles.add(File(path));
    }

    final userMessage = Message(
      id: -1, // Temp
      chatId: state.currentChatId,
      text: text,
      reasoning: "",
      type: MessageType.user,
      attachments: [], // The attachments get added when they are written to the database
      createdAt: DateTime.now(),
    );

    try {
      final msgs = await LocalDb.instance.messages;

      // Insert message and get actual database ID
      final insertedId = await msgs.insertMessage(userMessage,
          attachmentFiles: attachmentFiles);
      final validMessage = userMessage.copyWith(id: insertedId);

      await _sendToProvider(
        validMessage,
        attachmentPaths: attachmentPaths,
        insertUserMessage: false, // Already inserted
      );
    } catch (e) {
      emit(state.copyWith(
          errorMessage: 'Failed to send message: $e',
          isThinking: false)); // Stop thinking on error
    } finally {
      emit(state.copyWith(selectedAttachmentPaths: []));
    }
  }

  Future<void> removeAttachment(String pathToRemove) async {
    final updatedPaths = List<String>.from(state.selectedAttachmentPaths);
    updatedPaths.remove(pathToRemove);
    emit(state.copyWith(selectedAttachmentPaths: updatedPaths));
  }

  void stopGenerating() {
    state.responseStreamSubscription?.cancel();
    emit(state.copyWith(
        isResponding: false,
        isStreaming: false,
        isThinking: false)); // Clear any prior thinking state
  }

  void clearContext() {
    emit(state.copyWith(contextCleared: true));
  }

  Future<void> retryMessage(Message messageToRetry) async {
    final msgs = await LocalDb.instance.messages;
    final messages = await msgs.getMessages(state.currentChatId);

    // Find the user message that triggered this AI response
    final userMessageIndex =
        messages.indexWhere((m) => m.id == messageToRetry.id - 1 && m.isUser());

    if (userMessageIndex == -1) return;

    emit(state.copyWith(isThinking: true)); // Start thinking

    // Delete ONLY the target AI message
    await msgs.deleteMessage(messageToRetry.id);

    // Get messages up to (and including) the original user message
    final contextMessages =
        messages.sublist(0, userMessageIndex + 1).map((m) => m.text).toList();

    // Regenerate with original context
    await _sendToProvider(
      messages[userMessageIndex],
      insertUserMessage: false,
      contextMessages: contextMessages,
      attachmentPaths: [], //TODO Potentially add attachments
    );
  }

  Future<void> createNewChat(Folder? folder) async {
    if (state.selectedModel == null) return;

    emit(state.copyWith(isThinking: true)); // Start thinking
    // Initialize the model settings with the default values
    // But only for parameters that are actually available to modify (as provided by the API)
    // The default values
    Map<String, dynamic> newModelSettings = {};
    for (var settingName in state.selectedModel!.tunableParameters) {
      newModelSettings[settingName] = _findDefaultValueForParam(settingName);
    }

    final newChat = Chat(
      id: 0,
      folderId: folder?.id ??
          0, // set it to 0, and it will be attached to the "general" folder
      title: 'Chat with ${state.selectedModel!.name}',
      modelId: state.selectedModel!.id,
      createdAt: DateTime.now(),
      modelSettings: newModelSettings,
    );

    final chats = await LocalDb.instance.chats;
    final chatId = await chats.insertChat(newChat);
    emit(state.copyWith(
        currentChatId: chatId,
        isNewChat: false,
        isThinking: false)); // Clear thinking when new cat is created
  }

  Future<void> deleteAllChats() async {
    emit(state.copyWith(isThinking: true)); // Start thinking
    try {
      await LocalDb.instance.clearChats();
      emit(state.copyWith(
          chatsDeleted: true, isThinking: false)); // Flag for UI refresh
      emit(state.copyWith(chatsDeleted: false)); // Reset the flag
    } catch (e) {
      emit(state.copyWith(
          errorMessage: 'Failed to delete chats: $e', isThinking: false));
    }
  }

  Future<void> attachFiles(FileType fileType, List<String>? allowedExtensions,
      {int maxAttachments = 4}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowMultiple: true, // Allow multiple file selections
        allowedExtensions: allowedExtensions,
      );

      if (result != null && result.files.isNotEmpty) {
        List<String> paths =
            result.files.map((file) => file.path!).toList(); // Extract paths
        // Enforce max attachments limit
        if (state.selectedAttachmentPaths.length + paths.length >
            maxAttachments) {
          paths = paths.sublist(
              0,
              maxAttachments -
                  state.selectedAttachmentPaths
                      .length); //take how many we can from new list
        }

        final List<String> allPaths = List.from(state.selectedAttachmentPaths)
          ..addAll(paths);

        emit(state.copyWith(
            selectedAttachmentPaths: allPaths)); // Update state with the paths
      } else {
        // User canceled the picker
      }
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Error picking file: $e'));
    }
  }

  Future<LLModel?> getModelForChat(String modelId) async {
    final models = await provider.getModels();
    return models.firstWhere((m) => m.id == modelId);
  }

  Future<void> _sendToProvider(
    Message userMessage, {
    bool insertUserMessage = true,
    List<String>? contextMessages,
    List<String>? attachmentPaths,
  }) async {
    if (state.selectedModel == null) {
      emit(state.copyWith(errorMessage: 'Please select a model first'));
      return;
    }

    // create a chat instance
    final msgs = await LocalDb.instance.messages;
    emit(state.copyWith(
        isResponding: true,
        isStreaming: true,
        streamedResponse: '',
        streamedReasoning: '',
        isThinking: false // Model has started responding, stop thinking

        ));

    try {
      if (insertUserMessage) {
        //We do insert it but don't need to add attachmemnts here
        await msgs.insertMessage(userMessage);
      }

      // Use provided context or fetch fresh messages. Note ! state is immutable.
      final List<String> finalContext = contextMessages ??
          (await msgs.getMessages(state.currentChatId))
              .where((m) =>
                  m.id <=
                  userMessage.id) // Only messages up to target user message
              .map((m) => m.text)
              .toList();

      // If context was cleared, only use the latest user message
      final processedContext =
          state.contextCleared ? [userMessage.text] : finalContext;

      final stream = provider.streamResponse(
        state.selectedModel!.id,
        processedContext.join('\n'),
        state.modelSettings,
        attachmentPaths, //TODO potentially add attachments
      );

      StreamSubscription<TokenEvent> responseStreamSubscription =
          stream.listen((chunk) {
        if (chunk.type == TokenEventType.response) {
          emit(state.copyWith(
              streamedResponse: state.streamedResponse + chunk.text));
        } else if (chunk.type == TokenEventType.reasoning) {
          emit(state.copyWith(
              streamedReasoning: state.streamedReasoning + chunk.text));
        }
      }, onDone: () async {
        final aiMessage = Message(
          id: 0,
          chatId: state.currentChatId,
          text: state.streamedResponse,
          reasoning: state.streamedReasoning,
          type: MessageType.bot,
          createdAt: DateTime.now(),
          attachments: [], // AI message does not take attachments currently
        );

        await msgs.insertMessage(aiMessage);
        emit(state.copyWith(isResponding: false, isStreaming: false));
      }, onError: (e) {
        emit(state.copyWith(
          isResponding: false,
          isStreaming: false,
          isThinking: false, // Stop thinking on error
          errorMessage: 'Error: $e',
        ));
      });
      emit(state.copyWith(
          responseStreamSubscription: responseStreamSubscription));
    } catch (e, stacktrace) {
      emit(state.copyWith(
          errorMessage: 'SendToProvider: Error: $e',
          isResponding: false,
          isStreaming: false,
          isThinking: false // Stop thinking on (less common) synchronous error

          ));
      // print stack trace
      if (kDebugMode) {
        print(stacktrace);
      }
    }
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
}
