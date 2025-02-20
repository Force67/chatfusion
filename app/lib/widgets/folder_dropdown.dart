import 'package:flutter/material.dart';
import 'package:monkeychat/models/folder.dart';
import 'package:monkeychat/utils/folder_dialogue.dart';
import 'package:monkeychat/utils/folder_ui_service.dart';

class FolderDropdown extends StatefulWidget {
  final FolderService folderService;
  final Function(int?) onFolderSelected;

  const FolderDropdown(
      {Key? key, required this.folderService, required this.onFolderSelected})
      : super(key: key);

  @override
  _FolderDropdownState createState() => _FolderDropdownState();
}

class _FolderDropdownState extends State<FolderDropdown> {
  List<Folder> _folders = [];
  int? _selectedFolderId;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    _folders = await widget.folderService.loadFolders();
    if (_selectedFolderId == null ||
        !_folders.any((folder) => folder.id == _selectedFolderId)) {
      final defaultFolder = _folders.firstWhere(
        (folder) => folder.id == 1,
        orElse: () => _folders.first,
      );
      _selectedFolderId = defaultFolder.id;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
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
            onChanged: widget.onFolderSelected,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () {
            if (_selectedFolderId != null) {
              final folder =
                  _folders.firstWhere((f) => f.id == _selectedFolderId);
              FolderDialog.showRenameFolderDialog(
                context,
                folder,
                widget.folderService,
                _loadFolders,
                mounted, // Pass the mounted check
              );
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () {
            if (_selectedFolderId != null) {
              final folder =
                  _folders.firstWhere((f) => f.id == _selectedFolderId);
              FolderDialog.showDeleteFolderDialog(
                context,
                folder,
                widget.folderService,
                _loadFolders,
                mounted, // Pass the mounted check
              );
            }
          },
        ),
      ],
    );
  }
}
