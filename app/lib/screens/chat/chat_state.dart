// chat_state.dart
import 'dart:async';
import "package:chatfusion/models/llm.dart";

class ChatState {
  final int currentChatId;
  final bool isNewChat;
  final LLModel? selectedModel;
  final Map<String, dynamic> modelSettings;
  final String streamedResponse;
  final String streamedReasoning;
  final bool contextCleared;
  final List<String> selectedAttachmentPaths;
  final bool isResponding;
  final bool isStreaming;
  final StreamSubscription? responseStreamSubscription;
  final String? errorMessage;
  final bool chatsDeleted;
  final bool isThinking;
  //final int msgsSinceLastSummary;

  ChatState({
    // required this.modelSvc,
    this.currentChatId = -1,
    this.isNewChat = false,
    required this.selectedModel,
    required this.modelSettings,
    this.streamedResponse = "",
    this.streamedReasoning = "",
    this.contextCleared = false,
    this.selectedAttachmentPaths = const [],
    this.isResponding = false,
    this.isStreaming = false,
    this.responseStreamSubscription,
    this.errorMessage,
    this.chatsDeleted = false,
    this.isThinking = false,
  });

  factory ChatState.initial() => ChatState(
        currentChatId: 0,
        isNewChat: true,
        selectedModel: null,
        modelSettings: {},
        streamedResponse: '',
        streamedReasoning: '',
        contextCleared: false,
        selectedAttachmentPaths: [],
        isResponding: false,
        isStreaming: false,
        isThinking: false,
      );

  ChatState copyWith({
    int? currentChatId,
    bool? isNewChat,
    LLModel? selectedModel,
    Map<String, dynamic>? modelSettings,
    String? streamedResponse,
    String? streamedReasoning,
    bool? contextCleared,
    List<String>? selectedAttachmentPaths,
    bool? isResponding,
    bool? isStreaming,
    StreamSubscription? responseStreamSubscription,
    String? errorMessage,
    bool? chatsDeleted,
    bool? isThinking,
  }) {
    return ChatState(
      currentChatId: currentChatId ?? this.currentChatId,
      isNewChat: isNewChat ?? this.isNewChat,
      selectedModel: selectedModel ?? this.selectedModel,
      modelSettings: modelSettings ?? this.modelSettings,
      streamedResponse: streamedResponse ?? this.streamedResponse,
      streamedReasoning: streamedReasoning ?? this.streamedReasoning,
      contextCleared: contextCleared ?? this.contextCleared,
      selectedAttachmentPaths:
          selectedAttachmentPaths ?? this.selectedAttachmentPaths,
      isResponding: isResponding ?? this.isResponding,
      isStreaming: isStreaming ?? this.isStreaming,
      responseStreamSubscription:
          responseStreamSubscription ?? this.responseStreamSubscription,
      errorMessage: errorMessage,
      chatsDeleted: chatsDeleted ?? this.chatsDeleted,
      isThinking: isThinking ?? this.isThinking,
    );
  }
}
