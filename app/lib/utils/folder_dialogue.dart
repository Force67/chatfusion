import 'package:flutter/material.dart';
import 'package:monkeychat/models/folder.dart';
import 'package:monkeychat/utils/folder_ui_service.dart';

class FolderDialog {
  static Future<void> showAddFolderDialog(
    BuildContext context,
    FolderService folderService,
    Function onFolderAdded,
    bool isMounted, // Pass the mounted check as a parameter
  ) async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Folder'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final folderName = controller.text.trim();
              await folderService.addFolder(folderName);
              onFolderAdded();
              if (isMounted)
                Navigator.pop(context); // Use the passed mounted check
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  static Future<void> showRenameFolderDialog(
    BuildContext context,
    Folder folder,
    FolderService folderService,
    Function onFolderRenamed,
    bool isMounted, // Pass the mounted check as a parameter
  ) async {
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
              await folderService.renameFolder(folder, newName);
              onFolderRenamed();
              if (isMounted)
                Navigator.pop(context); // Use the passed mounted check
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  static Future<void> showDeleteFolderDialog(
    BuildContext context,
    Folder folder,
    FolderService folderService,
    Function onFolderDeleted,
    bool isMounted, // Pass the mounted check as a parameter
  ) async {
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
              Navigator.pop(context);
              try {
                await folderService.deleteFolder(folder.id!);
                onFolderDeleted();
              } catch (e) {
                if (isMounted) {
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
}
