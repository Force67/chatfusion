// chat_cubit.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:monkeychat/database/local_db.dart';
import 'package:monkeychat/models/chat.dart';
import 'package:monkeychat/models/message.dart';
import 'package:monkeychat/services/ai_provider.dart';
import 'package:monkeychat/models/llm.dart';
import 'package:file_picker/file_picker.dart';

import "chat_state.dart";

import "package:monkeychat/services/ai_provider_or.dart";

class ChatCubit extends Cubit<ChatState> {
  final AIProvider provider = AIProviderOpenrouter();

  ChatCubit() : super(ChatState.initial());

  Future<void> initChat(int chatId, LLModel selectedModel,
      Map<String, dynamic> modelSettings) async {
    emit(state.copyWith(
      currentChatId: chatId,
      isNewChat: false,
      selectedModel: selectedModel,
      modelSettings: modelSettings,
    ));
  }

  void selectModel(LLModel model) {
    emit(state.copyWith(selectedModel: model, modelSettings: {}));
  }

  void updateModelSettings(Map<String, dynamic> newSettings) {
    emit(state.copyWith(modelSettings: newSettings));
  }

  Future<void> sendMessage(String text, String? imagePath) async {
    if (state.selectedModel == null && imagePath == null) {
      emit(state.copyWith(errorMessage: 'Please select a model first'));
      return;
    }
    if (text.trim().isEmpty && imagePath == null) return;

    // Create temporary message with placeholder ID
    final userMessage = Message(
      id: -1, // Temporary invalid ID
      chatId: state.currentChatId,
      text: text,
      reasoning: "",
      isUser: true,
      createdAt: DateTime.now(),
    );

    try {
      // Insert message and get actual database ID
      final insertedId = await LocalDb.instance.insertMessage(userMessage);
      final validMessage = userMessage.copyWith(id: insertedId);

      await _sendToProvider(
        validMessage,
        imagePath: imagePath,
        insertUserMessage: false, // Already inserted
      );
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to send message: $e'));
    } finally {
      emit(state.copyWith(selectedImagePath: null));
    }
  }

  void stopGenerating() {
    state.responseStreamSubscription?.cancel();
    emit(state.copyWith(isResponding: false, isStreaming: false));
  }

  void clearContext() {
    emit(state.copyWith(contextCleared: true));
  }

  Future<void> retryMessage(Message messageToRetry) async {
    final messages = await LocalDb.instance.getMessages(state.currentChatId);

    // Find the user message that triggered this AI response
    final userMessageIndex =
        messages.indexWhere((m) => m.id == messageToRetry.id - 1 && m.isUser);

    if (userMessageIndex == -1) return;

    // Delete ONLY the target AI message
    await LocalDb.instance.deleteMessage(messageToRetry.id);

    // Get messages up to (and including) the original user message
    final contextMessages =
        messages.sublist(0, userMessageIndex + 1).map((m) => m.text).toList();

    // Regenerate with original context
    await _sendToProvider(
      messages[userMessageIndex],
      insertUserMessage: false,
      contextMessages: contextMessages,
    );
  }

  Future<void> createNewChat() async {
    if (state.selectedModel == null) return;

    // Initialize the model settings with the default values
    // But only for parameters that are actually available to modify (as provided by the API)
    // The default values
    Map<String, dynamic> newModelSettings = {};
    for (var settingName in state.selectedModel!.tunableParameters) {
      newModelSettings[settingName] = _findDefaultValueForParam(settingName);
    }

    final newChat = Chat(
      id: 0,
      title: 'Chat with ${state.selectedModel!.name}',
      modelId: state.selectedModel!.id,
      createdAt: DateTime.now(),
      modelSettings: newModelSettings,
    );

    final chats = await LocalDb.instance.chats;
    final chatId = await chats.insertChat(newChat);
    emit(state.copyWith(currentChatId: chatId, isNewChat: false));
  }

  Future<void> deleteAllChats() async {
    try {
      await LocalDb.instance.clearChats();
      emit(state.copyWith(chatsDeleted: true)); // Flag for UI refresh
      emit(state.copyWith(chatsDeleted: false)); // Reset the flag
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to delete chats: $e'));
    }
  }

  Future<void> attachFile(
      FileType fileType, List<String>? allowedExtensions) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
      );

      if (result != null && result.files.isNotEmpty) {
        final PlatformFile file = result.files.first;
        if (state.selectedModel!.supportsImageInput) {
          emit(state.copyWith(selectedImagePath: file.path));
        } else {
          // Handle text file selection logic if needed
          // For example:
          // String fileContent = await File(file.path!).readAsString();
          // emit(state.copyWith(textFromFile: fileContent));
        }
      }
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Error selecting file: $e'));
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
    String? imagePath,
  }) async {
    if (state.selectedModel == null) {
      emit(state.copyWith(errorMessage: 'Please select a model first'));
      return;
    }

    emit(state.copyWith(
        isResponding: true,
        isStreaming: true,
        streamedResponse: '',
        streamedReasoning: ''));

    try {
      if (insertUserMessage) {
        await LocalDb.instance.insertMessage(userMessage);
      }

      // Use provided context or fetch fresh messages. Note ! state is immutable.
      final List<String> finalContext = contextMessages ??
          (await LocalDb.instance.getMessages(state.currentChatId))
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
        imagePath: imagePath,
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
          isUser: false,
          createdAt: DateTime.now(),
        );

        await LocalDb.instance.insertMessage(aiMessage);
        emit(state.copyWith(isResponding: false, isStreaming: false));
      }, onError: (e) {
        emit(state.copyWith(
          isResponding: false,
          isStreaming: false,
          errorMessage: 'Error: $e',
        ));
      });
      emit(state.copyWith(
          responseStreamSubscription: responseStreamSubscription));
    } catch (e) {
      emit(state.copyWith(
          errorMessage: 'Error: $e', isResponding: false, isStreaming: false));
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
