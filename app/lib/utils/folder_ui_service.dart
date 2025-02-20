import 'package:monkeychat/database/local_db.dart';
import 'package:monkeychat/models/folder.dart';

class FolderService {
  final LocalDb localDb;

  FolderService(this.localDb);

  Future<void> addFolder(String folderName) async {
    if (folderName.isNotEmpty) {
      final folderColl = await localDb.folders;
      final newFolder = Folder(
        id: null,
        name: folderName,
        createdAt: DateTime.now(),
        systemFolder: false,
      );
      await folderColl.insertFolder(newFolder);
    }
  }

  Future<void> renameFolder(Folder folder, String newName) async {
    if (newName.isNotEmpty) {
      final updatedFolder = Folder(
        id: folder.id,
        name: newName,
        createdAt: folder.createdAt,
        systemFolder: false,
      );
      final folderColl = await localDb.folders;
      await folderColl.updateFolder(updatedFolder);
    }
  }

  Future<void> deleteFolder(int folderId) async {
    final folderColl = await localDb.folders;
    await folderColl.deleteFolder(folderId);
  }

  Future<List<Folder>> loadFolders() async {
    final folderColl = await localDb.folders;
    return await folderColl.getFolders();
  }
}
