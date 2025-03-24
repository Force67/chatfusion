import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:chatfusion/database/export_import.dart';
import '../database/local_db.dart';
import '../models/chat.dart';
import '../models/llm.dart';
import '../models/folder.dart';
import '../screens/stats/stats_screen.dart';
import '../screens/stats/stats_cubit.dart';
import '../services/ai_provider_or.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChatListSidebar extends StatefulWidget {
  final int? currentChatId;
  final Function(int) onChatSelected;
  final Function(Folder) onNewChat;
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
  final Map<int?, bool> _folderExpandedState =
      {}; // Track expanded state of folders

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final folderColl = await LocalDb.instance.folders;
    _folders = await folderColl.getFolders();
    setState(() {});
  }

  Future<List<Chat>> _loadChatsInFolder(int folderId) async {
    final db = LocalDb.instance;
    final chatscol = await db.chats;
    final folderColl = await db.folders;

    final chatIds = await folderColl.getChatsInFolder(folderId);
    if (chatIds.isEmpty) {
      return <Chat>[];
    }
    List<Chat> chats = [];
    for (final chat in chatIds) {
      final cht = await chatscol.getChat(chat.id);
      chats.add(cht);
    }
    return chats;
  }

  String _hexColorCodeFromColor(Color c) {
    return '#${c.value.toRadixString(16).substring(2)}';
  }

  Future<void> _createFolder(BuildContext context,
      {int? parentFolderId}) async {
    final TextEditingController folderNameController = TextEditingController();
    final TextEditingController folderPassController = TextEditingController();
    Color selectedColor = Colors.blue;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create New Folder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: folderNameController,
                decoration: const InputDecoration(hintText: 'Folder Name'),
              ),
              TextField(
                controller: folderPassController,
                decoration: const InputDecoration(hintText: 'Folder Password'),
              ),
              ColorPicker(
                pickerColor: selectedColor,
                onColorChanged: (color) {
                  selectedColor = color;
                },
                pickerAreaHeightPercent: 0.7,
                enableAlpha: false,
                displayThumbColor: true,
                showLabel: false,
                paletteType: PaletteType.hueWheel,
                pickerAreaBorderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(2),
                  topRight: Radius.circular(2),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final folderName = folderNameController.text.trim();
                if (folderName.isNotEmpty) {
                  final newFolder = Folder(
                    parentId: parentFolderId ?? 0,
                    name: folderName,
                    hexColorCode: _hexColorCodeFromColor(selectedColor),
                    hashedPassword: folderPassController.text.trim(),
                    createdAt: DateTime.now(),
                  );
                  final folderColl = await LocalDb.instance.folders;
                  await folderColl.add(newFolder);
                  await _loadFolders();
                  if (mounted) Navigator.of(context).pop();
                }
              },
              child: const Text('Create'),
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
            Row(
              children: [
                SizedBox(
                  width: 40,
                  child: IconButton(
                    icon: const Icon(Icons.create_new_folder),
                    onPressed: () => _createFolder(context),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _createFolder(context),
                  ),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildFolderList(context),
                  ],
                ),
              ),
            ),
            const Divider(), // Visual separator before the stats button
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ListTile(
                leading: const Icon(Icons.insert_chart), // Stats icon
                title: const Text('Stats'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BlocProvider(
                        create: (context) =>
                            BillingCubit(aiProvider: AIProviderOpenrouter()),
                        child: StatsOverview(),
                      ),
                    ),
                  );
                },
                //style: ListTileStyle.listitem,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                tileColor: Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .withOpacity(0.3),
              ),
            ),
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
        boxShadow: [
          // Add a subtle shadow
          BoxShadow(
            color:
                Colors.black.withOpacity(0.1), // Shadow color and transparency
            spreadRadius: 2,
            blurRadius: 6,
            offset: const Offset(0, 3), // changes position of shadow
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [],
      ),
    );
  }

  Widget _buildFolderList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _folders.where((folder) => folder.parentId == 0).map((folder) {
        // Only root folders
        final isExpanded = _folderExpandedState[folder.id] ?? false;
        return Container(
          // Added Container with BoxDecoration
          decoration: BoxDecoration(
            color: folder.hexColorCode.length == 7 &&
                    folder.hexColorCode[0] == '#'
                ? Color(int.parse(folder.hexColorCode.substring(1, 7),
                            radix: 16) +
                        0xFF000000)
                    .withOpacity(0.2)
                : Colors.grey.shade100
                    .withOpacity(0.2), // Default color if hex code is invalid
            border: Border.all(
              color: Colors.grey.shade300, // Light grey border
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8), // Optional: Rounded corners
          ),

          margin: const EdgeInsets.symmetric(
              vertical: 2, horizontal: 4), // added margin for spacing
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: Text(folder.name),
                leading: Icon(isExpanded ? Icons.folder_open : Icons.folder,
                    color:
                        _getFolderIconColor(folder)), // Use custom icon color
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        onPressed: () {
                          if (kDebugMode) {
                            print('New chat in folder ${folder.id}');
                          }
                          widget.onNewChat(folder);
                        },
                        icon: const Icon(Icons.add)),
                    PopupMenuButton(
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Text('Rename'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                        const PopupMenuItem(
                          value: 'export',
                          child: Text('Export Folder'),
                        ),
                        const PopupMenuItem(
                          value: 'import',
                          child: Text('Import into Folder'),
                        ),
                        const PopupMenuItem(
                          value: 'create_subfolder',
                          child: Text('Create subfolder'),
                        ),
                      ],
                      onSelected: (value) async {
                        if (value == 'rename') {
                          _renameFolder(context, folder);
                        } else if (value == 'delete') {
                          _confirmDeleteFolder(context, folder);
                        } else if (value == 'export') {
                          _exportFolder(context, folder);
                        } else if (value == 'import') {
                          await _importChats(context, folder.id!);
                        } else if (value == 'create_subfolder') {
                          _createFolder(context, parentFolderId: folder.id);
                        }
                      },
                    ),
                  ],
                ),
                onTap: () {
                  setState(() {
                    _folderExpandedState[folder.id] = !isExpanded;
                  });
                },
              ),
              if (isExpanded)
                Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildChatList(context, folder.id!),
                      _buildSubfolderList(context, folder.id!),
                    ],
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _exportFolder(BuildContext context, Folder folder) async {
    final exportImport = ExportImport();
    try {
      // Export all chats in the folder
      final jsonString = await exportImport.exportChatsToJson(folder.id!);

      // Allow the user to choose the export path
      final String? selectedDirectory =
          await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory == null) {
        // User canceled the file picker
        return;
      }

      // Save the JSON string to the chosen file
      final filePath =
          '$selectedDirectory/export_folder_${folder.name}_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File(filePath);
      await file.writeAsString(jsonString);

      // Show a success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Folder exported to $filePath'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting folder: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importChats(BuildContext context, int folderId) async {
    try {
      // Allow the user to select a file for import
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        // User canceled the file picker
        return;
      }

      // Read the selected file
      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();

      // Import the chats into the selected folder
      final exportImport = ExportImport();
      await exportImport.importChatsFromJson(jsonString, folderId);

      // Show a success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chats imported successfully into the folder'),
          ),
        );
      }

      // Refresh the UI
      await _loadFolders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing chats: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getFolderIconColor(Folder folder) {
    if (folder.hexColorCode.length == 7 && folder.hexColorCode[0] == '#') {
      try {
        return Color(int.parse(folder.hexColorCode.substring(1, 7), radix: 16) +
            0xFF000000);
      } catch (e) {
        // Handle parsing errors, return a default color
        return Colors.grey;
      }
    } else {
      // Return a default color if hex code is invalid
      return Colors.grey;
    }
  }

  Widget _buildSubfolderList(BuildContext context, int parentFolderId) {
    List<Folder> subfolders =
        _folders.where((folder) => folder.parentId == parentFolderId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: subfolders.map((folder) {
        final isExpanded = _folderExpandedState[folder.id] ?? false;
        return Container(
          // Added Container with BoxDecoration
          decoration: BoxDecoration(
            color: folder.hexColorCode.length == 7 &&
                    folder.hexColorCode[0] == '#'
                ? Color(int.parse(folder.hexColorCode.substring(1, 7),
                            radix: 16) +
                        0xFF000000)
                    .withOpacity(0.2)
                : Colors.grey.shade100
                    .withOpacity(0.2), // Default color if hex code is invalid
            border: Border.all(
              color: Colors.grey.shade300, // Light grey border
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8), // Optional: Rounded corners
          ),

          margin: const EdgeInsets.symmetric(
              vertical: 2, horizontal: 4), // added margin for spacing
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: Text(folder.name),
                leading: Icon(isExpanded ? Icons.folder_open : Icons.folder,
                    color:
                        _getFolderIconColor(folder)), // Use custom icon color
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        onPressed: () {
                          if (kDebugMode) {
                            print('New chat in folder ${folder.id}');
                          }
                          widget.onNewChat(folder);
                        },
                        icon: const Icon(Icons.add)),
                    PopupMenuButton(
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Text('Rename'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                        const PopupMenuItem(
                          value: 'export',
                          child: Text('Export Folder'),
                        ),
                        const PopupMenuItem(
                          value: 'import',
                          child: Text('Import into Folder'),
                        ),
                        const PopupMenuItem(
                          value: 'create_subfolder',
                          child: Text('Create subfolder'),
                        ),
                      ],
                      onSelected: (value) async {
                        if (value == 'rename') {
                          _renameFolder(context, folder);
                        } else if (value == 'delete') {
                          _confirmDeleteFolder(context, folder);
                        } else if (value == 'export') {
                          _exportFolder(context, folder);
                        } else if (value == 'import') {
                          await _importChats(context, folder.id!);
                        } else if (value == 'create_subfolder') {
                          _createFolder(context, parentFolderId: folder.id);
                        }
                      },
                    ),
                  ],
                ),
                onTap: () {
                  setState(() {
                    _folderExpandedState[folder.id] = !isExpanded;
                  });
                },
              ),
              if (isExpanded)
                Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: _buildChatList(context, folder.id!),
                ),
            ],
          ),
        );
      }).toList(),
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
                  parentId: folder.parentId,
                  id: folder.id,
                  name: newName,
                  hexColorCode: folder.hexColorCode,
                  hashedPassword: folder.hashedPassword,
                  createdAt: folder.createdAt,
                );
                final folderColl = await LocalDb.instance.folders;
                await folderColl.update(updatedFolder);
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
              final folderColl = await LocalDb.instance.folders;
              await folderColl.deleteFolderAndRemoveChatsFromFolder(folder.id!);
              await _loadFolders();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(BuildContext context, int folderId) {
    return FutureBuilder<List<Chat>>(
      future: _loadChatsInFolder(folderId),
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
            shrinkWrap: true, // Important for nesting in Column
            physics:
                const NeverScrollableScrollPhysics(), // Disable list's own scrolling
            padding: const EdgeInsets.only(top: 16),
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
            itemBuilder: (context, index) => _ChatListItem(
              chat: chats[index],
              isSelected: widget.currentChatId == chats[index].id,
              onTap: () => widget.onChatSelected(chats[index].id),
              getModelForChat: widget.getModelForChat,
              folderId: folderId,
              onFolderUpdated: () {
                setState(() {}); // Refresh sidebar after folder change
              },
            ),
          ),
        );
      },
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
  // Generate a random color gradient for each chat item
  final Color _startColor =
      Colors.primaries[Random().nextInt(Colors.primaries.length)].shade100;
  final Color _endColor =
      Colors.primaries[Random().nextInt(Colors.primaries.length)].shade50;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
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
              //_buildFolderAssignment(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderAssignment(BuildContext context) {
    return FutureBuilder<List<Folder>>(
      future: LocalDb.instance.folders.then((value) => value.getFolders()),
      builder: (context, foldersSnapshot) {
        return FutureBuilder<List<Folder>>(
          future: LocalDb.instance.folders
              .then((value) => value.getFoldersForChat(widget.chat.id)),
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
