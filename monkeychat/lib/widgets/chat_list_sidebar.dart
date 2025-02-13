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
      return Container(
        width: MediaQuery.of(context).size.width * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(4, 0),
            )
          ],
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              _buildChatList(context),
              _buildDeleteButton(context),
            ],
          ),
        ),
      );
    }

    Widget _buildHeader(BuildContext context) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: const BorderRadius.only(
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const FlutterLogo(size: 32),
                const SizedBox(width: 12),
                Text(
                  'MonkeyChat',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.add, size: 20),
                label: const Text('New Chat'),
                onPressed: onNewChat,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildChatList(BuildContext context) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: FutureBuilder<List<Chat>>(
            future: _loadChats(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final chats = snapshot.data ?? [];
              if (chats.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'No chats yet\nStart a new conversation!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                  ),
                );
              }

              return Material(
                color: Colors.transparent,
                child: ListView.separated(
                  padding: const EdgeInsets.only(top: 16),
                  itemCount: chats.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                  itemBuilder: (context, index) => _ChatListItem(
                    chat: chats[index],
                    isSelected: currentChatId == chats[index].id,
                    onTap: () => onChatSelected(chats[index].id),
                    getModelForChat: getModelForChat,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    Widget _buildDeleteButton(BuildContext context) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextButton.icon(
          icon: const Icon(Icons.delete_outline, size: 20),
          label: const Text('Delete All Chats'),
          onPressed: () => _confirmDelete(context),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    void _confirmDelete(BuildContext context) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete all chats?'),
          content: const Text('This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onDeleteAllChats();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }
  }

  class _ChatListItem extends StatelessWidget {
    final Chat chat;
    final bool isSelected;
    final VoidCallback onTap;
    final Future<LLModel?> Function(String) getModelForChat;

    const _ChatListItem({
      required this.chat,
      required this.isSelected,
      required this.onTap,
      required this.getModelForChat,
    });

    @override
    Widget build(BuildContext context) {
      return Material(
        color: isSelected
            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: Theme.of(context).colorScheme.primary)
                  : null,
            ),
            child: Row(
              children: [
                Icon(Icons.forum_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chat.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder<LLModel?>(
                        future: getModelForChat(chat.modelId),
                        builder: (context, snapshot) => Text(
                          snapshot.hasData
                              ? 'Model: ${snapshot.data!.name}'
                              : 'Model: Unknown',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.6),
                                fontSize: 12,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
