import 'package:monkeychat/models/chat.dart';
import 'package:monkeychat/models/folder.dart';
import 'package:sqflite/sqflite.dart';

class FolderCollection {
  final Database db;

  FolderCollection(this.db);

  Future<int> add(Folder f) async {
    //await _validateParent(f.parentId);
    final id = await db.insert('folders', {
      'name': f.name,
      'parent_id': f.parentId, // passing "null" is fine, nullable column
      'color_code': f.hexColorCode,
      'hashed_password': f.hashedPassword,
      'created_at': f.createdAt.toIso8601String(),
    });

    return id;
  }

  Future<void> remove(int folderId) async {
    return await db.transaction((txn) async {
      await _validateNoChildren(txn, folderId);

      final rowsDeleted = await txn.delete(
        'folders',
        where: 'id = ?',
        whereArgs: [folderId],
      );

      if (rowsDeleted == 0) {
        throw Exception('Folder not found');
      }
    });
  }

  Future<void> update(Folder f) async {
    await _validateParent(f.parentId);

    final rowsUpdated = await db.update(
      'folders',
      {
        'name': f.name,
        'parent_id': f.parentId,
        'hashed_password': f.hashedPassword,
        'created_at': f.createdAt.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [f.id],
    );

    if (rowsUpdated == 0) {
      throw Exception('Folder not found');
    }
  }

  Future<List<Folder>> getFolders() async {
    final maps = await db.query('folders', orderBy: 'created_at DESC');
    return maps.map((map) => Folder.fromMap(map)).toList();
  }

  Future<List<Chat>> getChatsInFolder(int folderId) async {
    final maps = await db.query(
      'chats',
      where: 'folder_id = ?',
      whereArgs: [folderId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Chat.fromMap(map)).toList();
  }

  Future<List<Folder>> getFoldersForChat(int chatId) async {
    final maps = await db.rawQuery('''
      SELECT folders.*
      FROM folders
      JOIN chats ON folders.id = chats.folder_id
      WHERE chats.id = ?
    ''', [chatId]);
    return maps.map((map) => Folder.fromMap(map)).toList();
  }

  Future<Folder?> findFolder(int folderId) async {
    final maps = await db.query(
      'folders',
      where: 'id = ?',
      whereArgs: [folderId],
    );
    return maps.isNotEmpty ? Folder.fromMap(maps.first) : null;
  }

  Future<void> addChatToFolder(int chatId, int folderId) async {
    // Verify folder exists
    final folder = await findFolder(folderId);
    if (folder == null) {
      throw Exception('Folder not found');
    }

    final rowsUpdated = await db.update(
      'chats',
      {'folder_id': folderId},
      where: 'id = ?',
      whereArgs: [chatId],
    );

    if (rowsUpdated == 0) {
      throw Exception('Chat not found');
    }
  }

  Future<void> _validateParent(int? parentId) async {
    if (parentId != null) {
      final parent = await findFolder(parentId);
      if (parent == null) {
        throw Exception('Parent folder not found');
      }
    }
  }

  Future<void> removeChatFromFolder(int chatId, int folderId) async {}

  Future<void> _validateNoChildren(Transaction txn, int folderId) async {
    final childFolders = await txn.query(
      'folders',
      where: 'parent_id = ?',
      whereArgs: [folderId],
      limit: 1,
    );
    if (childFolders.isNotEmpty) {
      throw Exception('Folder contains child folders');
    }

    final chats = await txn.query(
      'chats',
      where: 'folder_id = ?',
      whereArgs: [folderId],
      limit: 1,
    );
    if (chats.isNotEmpty) {
      throw Exception('Folder contains chats');
    }
  }

  Future<void> deleteFolderAndRemoveChatsFromFolder(int id) async {}
}
