import 'package:flutter/material.dart';
import 'package:monkeychat/database/chat_collection.dart';
import '../database/local_db.dart';
import '../models/chat.dart';
import '../models/llm.dart';
import '../models/folder.dart';

class ChatListSidebar extends StatefulWidget {
  final int? currentChatId;
  final Function(int) onChatSelected;
  final Function() onNewChat;
  final Function() onDeleteAllChats;
  final Future<LLModel?> Function(String) getModelForChat;

  ChatListSidebar({
    super.key,
    required this.currentChatId,
    required this.onChatSelected,
    required this.onNewChat,
    required this.onDeleteAllChats,
    required this.getModelForChat,
  });

  @override
  State<ChatListSidebar> createState() => _ChatListSidebarState();
}

class _ChatListSidebarState extends State<ChatListSidebar> {
  List<Folder> _folders = [];
  int? _selectedFolderId;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final folderColl = await LocalDb.instance.folders;
    _folders = await folderColl.getFolders();

    // Ensure a folder is always selected
    if (_selectedFolderId == null ||
        !_folders.any((folder) => folder.id == _selectedFolderId)) {
      // Default to folder with ID 1 if it exists
      final defaultFolder = _folders.firstWhere(
        (folder) => folder.id == 1,
        orElse: () => _folders.first, // Fallback to the first folder
      );
      _selectedFolderId = defaultFolder.id;
    }

    setState(() {});
  }

  Future<List<Chat>> _loadChats() async {
    final db = LocalDb.instance;
    final chatscol = await db.chats;
    final folderColl = await db.folders;

    if (_selectedFolderId != null) {
      final chatIds = await folderColl.getChatsInFolder(_selectedFolderId!);
      if (chatIds.isEmpty) {
        return <Chat>[];
      }
      List<Chat> chats = [];
      for (final chat in chatIds) {
        final cht = await chatscol.getChat(chat.id);
        chats.add(cht);
      }
      return chats;
    } else {
      return await chatscol.getChats();
    }
  }

  void _onFolderSelected(int? folderId) {
    setState(() {
      _selectedFolderId = folderId;
    });
  }

  Future<void> _renameFolder(BuildContext context, Folder folder) async {
    final controller = TextEditingController(text: folder.name);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final updatedFolder = Folder(
                  id: folder.id,
                  name: newName,
                  createdAt: folder.createdAt,
                  systemFolder: false,
                );
                final folderColl = await LocalDb.instance.folders;
                await folderColl.updateFolder(updatedFolder);
                await _loadFolders();
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteFolder(BuildContext context, Folder folder) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder?'),
        content: const Text('This will only remove the folder, not the chats.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Close the dialog immediately after pressing "Delete"
              Navigator.pop(context);

              try {
                final folderColl = await LocalDb.instance.folders;
                await folderColl.deleteFolder(folder.id!);

                // Reset _selectedFolderId if it matches the deleted folder's ID
                if (_selectedFolderId == folder.id) {
                  setState(() {
                    _selectedFolderId = null;
                  });
                }

                // Refresh the folders list
                await _loadFolders();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete folder: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderDropdown(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButton<int>(
            value: _selectedFolderId,
            hint: const Text('Select Folder'),
            isExpanded: true,
            items: _folders.map((folder) {
              return DropdownMenuItem<int>(
                value: folder.id,
                child: Text(folder.name),
              );
            }).toList(),
            onChanged: _onFolderSelected,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () {
            if (_selectedFolderId != null) {
              final folder = _folders.firstWhere(
                (f) => f.id == _selectedFolderId,
              );
              _renameFolder(context, folder);
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () {
            if (_selectedFolderId != null) {
              final folder = _folders.firstWhere(
                (f) => f.id == _selectedFolderId,
              );
              _confirmDeleteFolder(context, folder);
            }
          },
        ),
      ],
    );
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
            const Divider(),
            _buildDeleteButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              const FlutterLogo(size: 24),
              const SizedBox(width: 8),
              Text(
                'MonkeyChat',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFolderDropdown(context),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: () async {
                  await widget.onNewChat(); // Trigger the new chat creation
                  if (_selectedFolderId != null) {
                    final folderColl = await LocalDb.instance.folders;
                    final chats = await LocalDb.instance.chats;
                    final latestChat = await chats.getLatestChat();
                    if (latestChat != null) {
                      await folderColl.addChatToFolder(
                          latestChat.id, _selectedFolderId!);
                    }
                  }
                  setState(() {}); // Refresh the sidebar
                },
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                ),
              );
            }

            return Material(
              color: Colors.transparent,
              child: ListView.separated(
                padding: const EdgeInsets.only(top: 16),
                itemCount: chats.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 16),
                itemBuilder: (context, index) => _ChatListItem(
                  chat: chats[index],
                  isSelected: widget.currentChatId == chats[index].id,
                  onTap: () => widget.onChatSelected(chats[index].id),
                  getModelForChat: widget.getModelForChat,
                  folderId: _selectedFolderId,
                  onFolderUpdated: () {
                    setState(() {}); // Refresh sidebar after folder change
                  },
                  onChatDeleted: () {
                    setState(() {}); // Refresh sidebar after chat deletion
                  },
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
              widget.onDeleteAllChats();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _ChatListItem extends StatefulWidget {
  final Chat chat;
  final bool isSelected;
  final VoidCallback onTap;
  final Future<LLModel?> Function(String) getModelForChat;
  final int? folderId;
  final VoidCallback onFolderUpdated;
  final VoidCallback onChatDeleted;

  const _ChatListItem({
    required this.chat,
    required this.isSelected,
    required this.onTap,
    required this.getModelForChat,
    this.folderId,
    required this.onFolderUpdated,
    required this.onChatDeleted,
  });

  @override
  State<_ChatListItem> createState() => _ChatListItemState();
}

class _ChatListItemState extends State<_ChatListItem> {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.isSelected
          ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
          : Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: widget.isSelected
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
                      widget.chat.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    FutureBuilder<LLModel?>(
                      future: widget.getModelForChat(widget.chat.modelId),
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
              PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Text('Rename'),
                  ),
                  const PopupMenuItem(
                    value: 'move',
                    child: Text('Move to Folder'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'rename') {
                    _renameChat(context);
                  } else if (value == 'move') {
                    _moveChatToFolder(context);
                  } else if (value == 'delete') {
                    _confirmDeleteChat(context);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _renameChat(BuildContext context) async {
    final controller = TextEditingController(text: widget.chat.title);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Chat'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final updatedChat = Chat(
                  id: widget.chat.id,
                  title: newName,
                  modelId: widget.chat.modelId,
                  createdAt: widget.chat.createdAt,
                  modelSettings: widget.chat.modelSettings,
                );
                final chatColl = await LocalDb.instance.chats;
                await chatColl.updateChat(updatedChat);
                widget.onFolderUpdated();
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteChat(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final db = await LocalDb.instance.database;
              await db.transaction((txn) async {
                final chatColl = ChatCollection(db);
                await chatColl.deleteChat(txn, widget.chat.id);
              });
              widget.onChatDeleted();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _moveChatToFolder(BuildContext context) async {
    final folderColl = await LocalDb.instance.folders;
    final allFolders = await folderColl.getFolders();

    // Get the folders the chat is currently assigned to
    final selectedFolders = await folderColl.getFoldersForChat(widget.chat.id);
    final selectedFolderIds = selectedFolders.map((f) => f.id).toSet();

    _showFolderSelectionDialog(
      context,
      allFolders,
      selectedFolderIds,
      onFolderUpdated: widget.onFolderUpdated, // Pass the callback
    );
  }

  void _showFolderSelectionDialog(
    BuildContext context,
    List<Folder> allFolders,
    Set<int?> selectedFolderIds, {
    required VoidCallback onFolderUpdated, // Add the callback parameter
  }) async {
    // Create a temporary copy of selected folder IDs for local state management
    final tempSelected = Set<int?>.from(selectedFolderIds);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Select Folders'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: allFolders.length,
                itemBuilder: (context, index) {
                  final folder = allFolders[index];
                  return CheckboxListTile(
                    title: Text(folder.name),
                    value: tempSelected.contains(folder.id),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          tempSelected.add(folder.id);
                        } else {
                          tempSelected.remove(folder.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final folderColl = await LocalDb.instance.folders;
                  // Identify folders that were deselected
                  final deselectedFolders =
                      selectedFolderIds.difference(tempSelected);

                  // Remove the chat from deselected folders
                  for (final folderId in deselectedFolders) {
                    if (folderId != null) {
                      await folderColl.removeChatFromFolder(
                          widget.chat.id, folderId);
                    }
                  }

                  // Identify newly selected folders
                  final newlySelectedFolders =
                      tempSelected.difference(selectedFolderIds);

                  // Add the chat to newly selected folders
                  for (final folderId in newlySelectedFolders) {
                    if (folderId != null) {
                      await folderColl.addChatToFolder(
                          widget.chat.id, folderId);
                    }
                  }

                  // Update the selected folder IDs in the widget state
                  selectedFolderIds.clear();
                  selectedFolderIds.addAll(tempSelected);

                  if (mounted) {
                    Navigator.pop(context); // Close the dialog
                    onFolderUpdated(); // Trigger sidebar refresh
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
