import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:monkeychat/database/export_import.dart';
import 'package:monkeychat/database/folder_collection.dart';
import 'package:path_provider/path_provider.dart';
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
  Map<int?, bool> _folderExpandedState = {}; // Track expanded state of folders

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

  Future<void> _createFolder(BuildContext context,
      {int? parentFolderId}) async {
    final TextEditingController folderNameController = TextEditingController();
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

  String _hexColorCodeFromColor(Color c) {
    return '#${c.value.toRadixString(16).substring(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final ExportImport exportImport = ExportImport();

    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(4, 0),
          ),
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
            const Divider(),
            // Add the export/import buttons here
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      // Export data to JSON
                      final jsonString = await exportImport.exportChatsToJson();

                      // Convert JSON string to bytes
                      final jsonBytes = utf8.encode(jsonString);

                      // Allow user to choose where to save the JSON file
                      final String? outputFilePath =
                          await FilePicker.platform.saveFile(
                        dialogTitle: 'Export chats to JSON',
                        fileName: 'chats_export.json',
                        allowedExtensions: ['json'],
                        bytes: jsonBytes, // Pass the bytes here
                      );

                      if (outputFilePath != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Chats exported to $outputFilePath'),
                          ),
                        );
                      }
                    },
                    child: const Text('Export to JSON'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      // Allow user to select a JSON file for import
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['json'],
                      );
                      if (result != null) {
                        final file = File(result.files.single.path!);
                        final jsonString = await file.readAsString();

                        // Show folder selection dialog
                        final folderColl = await LocalDb.instance.folders;
                        final folders = await folderColl.getFolders();
                        final selectedFolderId =
                            await selectFolder(context, folders);

                        if (selectedFolderId != null) {
                          await exportImport.importChatsFromJson(
                            jsonString,
                            selectedFolderId,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Chats imported from JSON'),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Import from JSON'),
                  ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ListTile(
                leading: const Icon(Icons.insert_chart),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
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
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 6,
            offset: const Offset(0, 3),
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
        return Container(
          decoration: BoxDecoration(
            color: folder.hexColorCode != null &&
                    folder.hexColorCode!.length == 7 &&
                    folder.hexColorCode![0] == '#'
                ? Color(int.parse(folder.hexColorCode!.substring(1, 7),
                            radix: 16) +
                        0xFF000000)
                    .withOpacity(0.2)
                : Colors.grey.shade100.withOpacity(0.2),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: Text(folder.name),
                leading: Icon(Icons.folder),
                trailing: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    widget.onNewChat(folder);
                  },
                ),
                onTap: () {
                  setState(() {
                    _folderExpandedState[folder.id] =
                        !(_folderExpandedState[folder.id] ?? false);
                  });
                },
              ),
              if (_folderExpandedState[folder.id] ?? false)
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
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
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
                setState(() {});
              },
            ),
          ),
        );
      },
    );
  }

  Future<int?> selectFolder(BuildContext context, List<Folder> folders) async {
    int? selectedFolderId;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Folder'),
          content: DropdownButton<int>(
            hint: const Text('Choose a folder'),
            value: selectedFolderId,
            onChanged: (value) {
              selectedFolderId = value;
              Navigator.pop(context);
            },
            items: folders.map((folder) {
              return DropdownMenuItem<int>(
                value: folder.id,
                child: Text(folder.name),
              );
            }).toList(),
          ),
        );
      },
    );
    return selectedFolderId;
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
