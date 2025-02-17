// chat_state.dart
import 'dart:async';
import "package:monkeychat/models/llm.dart";

class ChatState {
  final int currentChatId;
  final bool isNewChat;
  final LLModel? selectedModel;
  final Map<String, dynamic> modelSettings;
  final String streamedResponse;
  final String streamedReasoning;
  final bool contextCleared;
  final String? selectedImagePath;
  final bool isResponding;
  final bool isStreaming;
  final StreamSubscription? responseStreamSubscription;
  final String? errorMessage;
  final bool chatsDeleted;

  ChatState({
    required this.currentChatId,
    required this.isNewChat,
    required this.selectedModel,
    required this.modelSettings,
    required this.streamedResponse,
    required this.streamedReasoning,
    required this.contextCleared,
    required this.selectedImagePath,
    required this.isResponding,
    required this.isStreaming,
    this.responseStreamSubscription,
    this.errorMessage,
    this.chatsDeleted = false,
  });

  factory ChatState.initial() => ChatState(
    currentChatId: 0,
    isNewChat: true,
    selectedModel: null,
    modelSettings: {},
    streamedResponse: '',
    streamedReasoning: '',
    contextCleared: false,
    selectedImagePath: null,
    isResponding: false,
    isStreaming: false,
  );

  ChatState copyWith({
    int? currentChatId,
    bool? isNewChat,
    LLModel? selectedModel,
    Map<String, dynamic>? modelSettings,
    String? streamedResponse,
    String? streamedReasoning,
    bool? contextCleared,
    String? selectedImagePath,
    bool? isResponding,
    bool? isStreaming,
    StreamSubscription? responseStreamSubscription,
    String? errorMessage,
    bool? chatsDeleted,
  }) {
    return ChatState(
      currentChatId: currentChatId ?? this.currentChatId,
      isNewChat: isNewChat ?? this.isNewChat,
      selectedModel: selectedModel ?? this.selectedModel,
      modelSettings: modelSettings ?? this.modelSettings,
      streamedResponse: streamedResponse ?? this.streamedResponse,
      streamedReasoning: streamedReasoning ?? this.streamedReasoning,
      contextCleared: contextCleared ?? this.contextCleared,
      selectedImagePath: selectedImagePath ?? this.selectedImagePath,
      isResponding: isResponding ?? this.isResponding,
      isStreaming: isStreaming ?? this.isStreaming,
      responseStreamSubscription: responseStreamSubscription ?? this.responseStreamSubscription,
      errorMessage: errorMessage,
      chatsDeleted: chatsDeleted ?? this.chatsDeleted,
    );
  }
}
