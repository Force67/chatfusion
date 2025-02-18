import 'package:monkeychat/database/chat_collection.dart';
import 'package:monkeychat/models/chat.dart';
import 'package:monkeychat/models/folder.dart';
import 'package:sqflite/sqflite.dart';

class FolderCollection {
  final Database db;

  FolderCollection(this.db);

  Future<int> insertFolder(Folder folder) async {
    return db.insert('folders', folder.toMap());
  }

  Future<List<Folder>> getFolders() async {
    final maps = await db.query('folders', orderBy: 'created_at DESC');
    return maps.map((map) => Folder.fromMap(map)).toList();
  }

  Future<Folder?> getFolderById(int id) async {
    final List<Map<String, dynamic>> maps = await db.query(
      'folders',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Folder.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<void> addChatToFolder(int chatId, int folderId) async {
    // Check if the record already exists
    final existingRecord = await db.query(
      'folders_to_chats',
      where: 'chat_id = ? AND folder_id = ?',
      whereArgs: [chatId, folderId],
    );

    if (existingRecord.isNotEmpty) {
      // If the record exists, update it (if needed)
      await db.update(
        'folders_to_chats',
        {
          'created_at':
              DateTime.now().toIso8601String(), // Update the timestamp
        },
        where: 'chat_id = ? AND folder_id = ?',
        whereArgs: [chatId, folderId],
      );
    } else {
      // If the record does not exist, insert it
      await db.insert(
        'folders_to_chats',
        {
          'chat_id': chatId,
          'folder_id': folderId,
          'created_at':
              DateTime.now().toIso8601String(), // Include the timestamp
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> removeChatFromFolder(int chatId, int folderId) async {
    await db.delete(
      'folders_to_chats',
      where: 'chat_id = ? AND folder_id = ?',
      whereArgs: [chatId, folderId],
    );
  }

  Future<List<Chat>> getChatsInFolder(int folderId) async {
    final maps = await db.rawQuery('''
      SELECT chats.* FROM chats
      INNER JOIN folders_to_chats ON chats.id = folders_to_chats.chat_id
      WHERE folders_to_chats.folder_id = ?
      ORDER BY folders_to_chats.created_at DESC
    ''', [folderId]);

    return maps.map(Chat.fromMap).toList();
  }

  Future<void> updateFolder(Folder folder) async {
    await db.update(
      'folders',
      folder.toMap(),
      where: 'id = ?',
      whereArgs: [folder.id],
    );
  }

  Future<void> deleteFolder(int folderId) async {
    final folder = await getFolderById(folderId);
    if (folder != null && folder.systemFolder == true) {
      throw Exception('Cannot delete system folder');
    }
    await db.transaction((txn) async {
      // Let foreign key cascade handle the relationships
      await txn.delete(
        'folders',
        where: 'id = ?',
        whereArgs: [folderId],
      );

      final ChatCollection chatCollection = ChatCollection(db);
      await chatCollection.findOrphanedChats(txn);
    });
  }

  Future<void> deleteOrphanedFolders(Transaction txn) async {
    // Get all folders that have no associated chats
    final orphanedFolders = await txn.rawQuery('''
    SELECT f.id
    FROM folders f
    LEFT JOIN folders_to_chats ftc ON f.id = ftc.folder_id
    WHERE ftc.chat_id IS NULL
  ''');

    // Delete orphaned folders
    for (final folder in orphanedFolders) {
      final folderId = folder['id'] as int;
      await txn.delete(
        'folders',
        where: 'id = ?',
        whereArgs: [folderId],
      );
    }
  }

  Future<List<Folder>> getFoldersForChat(int chatId) async {
    final maps = await db.rawQuery('''
    SELECT folders.* FROM folders
    INNER JOIN folders_to_chats ON folders.id = folders_to_chats.folder_id
    WHERE folders_to_chats.chat_id = ?
  ''', [chatId]);
    return maps.map((map) => Folder.fromMap(map)).toList();
  }

  Future<void> updateChatFolders(int chatId, List<int> folderIds) async {
    await db.transaction((txn) async {
      // Remove existing relationships
      await txn.delete(
        'folders_to_chats',
        where: 'chat_id = ?',
        whereArgs: [chatId],
      );

      // Add new relationships
      final now = DateTime.now().toIso8601String();
      for (final folderId in folderIds) {
        await txn.insert(
          'folders_to_chats',
          {
            'folder_id': folderId,
            'chat_id': chatId,
            'created_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }
}
