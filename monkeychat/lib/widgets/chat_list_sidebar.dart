import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/chat.dart';
import '../models/llm.dart';

class ChatListSidebar extends StatelessWidget {
  final int? currentChatId;
  final Function(int) onChatSelected;
  final Function() onNewChat;
  final Function() onDeleteAllChats;
  final Future<LLModel?> Function(String) getModelForChat;

  const ChatListSidebar({
    super.key,
    required this.currentChatId,
    required this.onChatSelected,
    required this.onNewChat,
    required this.onDeleteAllChats,
    required this.getModelForChat,
  });

  Future<List<Chat>> _loadChats() async {
    return await DatabaseHelper.instance.getChats();
  }

  @override
  Widget build(BuildContext context) {
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
                'Monkeychat',
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
                onPressed: onNewChat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blueGrey,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Chat>>(
            future: _loadChats(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final chats = snapshot.data!;
              return ListView.builder(
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  return ListTile(
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: Text(chat.title),
                    subtitle: FutureBuilder<LLModel?>(
                      future: getModelForChat(chat.modelId),
                      builder: (context, snapshot) => Text(
                        snapshot.hasData
                            ? 'Model: ${snapshot.data!.name}'
                            : 'Unknown model',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    onTap: () => onChatSelected(chat.id),
                    selected: currentChatId == chat.id,
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Delete All Chats'),
            onPressed: onDeleteAllChats,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
