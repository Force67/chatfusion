import 'package:flutter/material.dart';
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

  const ChatListSidebar({
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
    _folders = await LocalDb.instance.getFolders();
    setState(() {});
  }

  Future<List<Chat>> _loadChats() async {
    final db = LocalDb.instance;

    final chatscol = await db.chats;
    if (_selectedFolderId != null) {
      final chatIds = await db.getChatsInFolder(_selectedFolderId!);
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

  Future<void> _createFolder(BuildContext context) async {
    final TextEditingController folderNameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create New Folder'),
          content: TextField(
            controller: folderNameController,
            decoration: const InputDecoration(hintText: 'Folder Name'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Create'),
              onPressed: () async {
                final folderName = folderNameController.text.trim();
                if (folderName.isNotEmpty) {
                  final newFolder = Folder(
                    name: folderName,
                    createdAt: DateTime.now(),
                  );
                  await LocalDb.instance.insertFolder(newFolder);
                  await _loadFolders();
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
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
            _buildFolderList(context),
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
              onPressed: widget.onNewChat,
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

  Widget _buildFolderList(BuildContext context) {
    return ExpansionTile(
      title: const Text('Folders'),
      initiallyExpanded: true,
      children: [
        ..._folders.map((folder) => ListTile(
              title: Text(folder.name),
              leading: _selectedFolderId == folder.id
                  ? const Icon(Icons.folder)
                  : const Icon(Icons.folder_open),
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Text('Rename'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'rename') {
                    _renameFolder(context, folder);
                  } else if (value == 'delete') {
                    _confirmDeleteFolder(context, folder);
                  }
                },
              ),
              onTap: () {
                setState(() {
                  _selectedFolderId =
                      _selectedFolderId == folder.id ? null : folder.id;
                });
              },
            )),
        ListTile(
          leading: const Icon(Icons.create_new_folder),
          title: const Text('New folder'),
          onTap: () => _createFolder(context),
        ),
      ],
    );
  }

  void _renameFolder(BuildContext context, Folder folder) async {
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
                );
                await LocalDb.instance.updateFolder(updatedFolder);
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

  void _confirmDeleteFolder(BuildContext context, Folder folder) async {
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
              await LocalDb.instance
                  .deleteFolderAndRemoveChatsFromFolder(folder.id!);
              await _loadFolders();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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

  const _ChatListItem({
    required this.chat,
    required this.isSelected,
    required this.onTap,
    required this.getModelForChat,
    this.folderId,
    required this.onFolderUpdated,
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
              _buildFolderAssignment(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderAssignment(BuildContext context) {
    return FutureBuilder<List<Folder>>(
      future: LocalDb.instance.getFolders(),
      builder: (context, foldersSnapshot) {
        return FutureBuilder<List<Folder>>(
          future: LocalDb.instance.getFoldersForChat(widget.chat.id),
          builder: (context, selectedFoldersSnapshot) {
            final allFolders = foldersSnapshot.data ?? [];
            final selectedFolders = selectedFoldersSnapshot.data ?? [];
            final selectedFolderIds = selectedFolders.map((f) => f.id).toSet();

            return IconButton(
              icon: const Icon(Icons.folder_open),
              onPressed: () => _showFolderSelectionDialog(
                context,
                allFolders,
                selectedFolderIds,
              ),
            );
          },
        );
      },
    );
  }

  void _showFolderSelectionDialog(
    BuildContext context,
    List<Folder> allFolders,
    Set<int?> selectedFolderIds,
  ) async {
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
                  // Identify folders that were deselected
                  final deselectedFolders =
                      selectedFolderIds.difference(tempSelected);

                  // Remove the chat from deselected folders
                  for (final folderId in deselectedFolders) {
                    if (folderId != null) {
                      await LocalDb.instance
                          .removeChatFromFolder(widget.chat.id, folderId);
                    }
                  }

                  // Identify newly selected folders
                  final newlySelectedFolders =
                      tempSelected.difference(selectedFolderIds);

                  // Add the chat to newly selected folders
                  for (final folderId in newlySelectedFolders) {
                    if (folderId != null) {
                      await LocalDb.instance
                          .addChatToFolder(widget.chat.id, folderId);
                    }
                  }

                  // Update the selected folder IDs in the widget state
                  selectedFolderIds.clear();
                  selectedFolderIds.addAll(tempSelected);

                  if (mounted) {
                    Navigator.pop(context);
                    widget.onFolderUpdated(); // Trigger sidebar refresh
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
