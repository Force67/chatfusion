import 'package:flutter/foundation.dart';
import 'package:monkeychat/models/folder.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/llm.dart';
import 'dart:convert';

import 'chat_collection.dart';

class LocalDb {
  static final LocalDb instance = LocalDb._private();
  static Database? _database;
  static const int _version = 3; // Updated version

  Database? _cachedDb;
  ChatCollection? _chatCollection;

  LocalDb._private();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    _cachedDb = _database;
    return _database!;
  }

  Future<ChatCollection> get chats async {
    final db = _cachedDb ?? await database;
    _chatCollection ??= ChatCollection(db);
    return _chatCollection!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'chat_database.db');
    if (kDebugMode) {
      print('Database path: $path');
    }

    return openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        // Enable foreign key constraints
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
    CREATE TABLE folders(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
  ''');

    await db.execute('''
    CREATE TABLE folders_to_chats(
      folder_id INTEGER NOT NULL,
      chat_id INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      PRIMARY KEY (folder_id, chat_id),
      FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE CASCADE,
      FOREIGN KEY (chat_id) REFERENCES chats(id) ON DELETE CASCADE
    );
    ''');

    await db.execute('''
      CREATE TABLE chats(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        model_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        params TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chat_id INTEGER NOT NULL,
        text TEXT NOT NULL,
        reasoning TEXT,
        is_user INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(chat_id) REFERENCES chats(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE cached_models(
        model_id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        cached_at TEXT NOT NULL
      );
    ''');
    if (kDebugMode) {
      print("CREATED THE DB");
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // Proper migration to version 3
      await db.execute('DROP TABLE IF EXISTS folders_to_chats');
      await db.execute('DROP TABLE IF EXISTS folders');

      await db.execute('''
        CREATE TABLE folders(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          created_at TEXT NOT NULL
        );
      ''');

      await db.execute('''
        CREATE TABLE folders_to_chats(
          folder_id INTEGER NOT NULL,
          chat_id INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          PRIMARY KEY (folder_id, chat_id),
          FOREIGN KEY (folder_id) REFERENCES folders(id) ON DELETE CASCADE,
          FOREIGN KEY (chat_id) REFERENCES chats(id) ON DELETE CASCADE
        );
      ''');
    }
  }

  // Updated clear methods to handle schema changes
  Future<void> clearAll({bool deleteFolders = true}) async {
    //TODO: replace Placeholder boolean and actual implementation in GUI
    final db = await instance.database;
    await db.transaction((txn) async {
      // 1. Crucially, remove all folder relationships first
      await txn.delete('folders_to_chats');

      // 2. Delete all chats and messages
      await txn.delete('chats');
      await txn.delete('messages');
      await txn.delete('cached_models');

      // 3. Optionally delete all folders
      if (deleteFolders) {
        // Ensure you delete from 'folders' AFTER deleting relationships from 'folders_to_chats'
        await txn.delete('folders');
      }
    });
  }

  Future<void> clearChats() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('chats');
      await txn.delete('messages');
      await txn
          .delete('folders_to_chats'); // Crucial: remove folder relationships
    });
  }

  // Rest of the methods remain similar with added type safety...
  Future<int> insertMessage(Message message) async {
    final db = await instance.database;
    return db.insert('messages', {
      'chat_id': message.chatId,
      'text': message.text,
      'reasoning': message.reasoning,
      'is_user': message.isUser ? 1 : 0,
      'created_at': message.createdAt.toIso8601String(),
    });
  }

  Future<void> deleteMessage(int messageId) async {
    final db = await instance.database;
    await db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<List<Message>> getMessages(int chatId) async {
    final db = await instance.database;
    final maps = await db.query(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'created_at',
    );
    return maps.map((map) => Message.fromMap(map)).toList();
  }

  // Improved model caching with transaction
  Future<void> cacheModels(List<LLModel> models) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('cached_models');
      for (final model in models) {
        await txn.insert('cached_models', {
          'model_id': model.id,
          'data': jsonEncode(model.toJson()),
          'cached_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<List<LLModel>> getCachedModels() async {
    final db = await instance.database;
    final maps = await db.query('cached_models');
    return maps.map((map) {
      return LLModel.fromJson(
        jsonDecode(map['data'] as String),
      );
    }).toList();
  }

  Future<int> insertFolder(Folder folder) async {
    final db = await instance.database;
    return db.insert('folders', folder.toMap());
  }

  Future<List<Folder>> getFolders() async {
    final db = await instance.database;
    final maps = await db.query('folders', orderBy: 'created_at DESC');
    return maps.map((map) => Folder.fromMap(map)).toList();
  }

  Future<void> addChatToFolder(int chatId, int folderId) async {
    final db = await instance.database;

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
    final db = await instance.database;
    await db.delete(
      'folders_to_chats',
      where: 'chat_id = ? AND folder_id = ?',
      whereArgs: [chatId, folderId],
    );
  }

  Future<List<Chat>> getChatsInFolder(int folderId) async {
    final db = await instance.database;
    final maps = await db.rawQuery('''
      SELECT chats.* FROM chats
      INNER JOIN folders_to_chats ON chats.id = folders_to_chats.chat_id
      WHERE folders_to_chats.folder_id = ?
      ORDER BY folders_to_chats.created_at DESC
    ''', [folderId]);

    return maps.map(Chat.fromMap).toList();
  }

  Future<void> updateFolder(Folder folder) async {
    final db = await instance.database;
    await db.update(
      'folders',
      folder.toMap(),
      where: 'id = ?',
      whereArgs: [folder.id],
    );
  }

  Future<void> deleteFolder(int folderId) async {
    final db = await instance.database;
    await db.delete(
      'folders',
      where: 'id = ?',
      whereArgs: [folderId],
    );
  }

  Future<void> deleteFolderAndRemoveChatsFromFolder(int folderId) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      // Let foreign key cascade handle the relationships
      await txn.delete(
        'folders',
        where: 'id = ?',
        whereArgs: [folderId],
      );
    });
  }

  Future<void> deleteFolderAndChats(int folderId) async {
    final db = await instance.database;

    await db.transaction((txn) async {
      // 1. First delete the folder (this will cascade to folders_to_chats)
      await txn.delete(
        'folders',
        where: 'id = ?',
        whereArgs: [folderId],
      );

      // 2. Find orphaned chats (not in any folders)
      final orphanedChats = await txn.rawQuery('''
      SELECT chats.id FROM chats
      LEFT JOIN folders_to_chats ON chats.id = folders_to_chats.chat_id
      WHERE folders_to_chats.chat_id IS NULL
    ''');

      // 3. Delete orphaned chats and their messages in batch
      if (orphanedChats.isNotEmpty) {
        final chatIds = orphanedChats.map((c) => c['id'] as int).toList();

        await txn.delete(
          'messages',
          where: 'chat_id IN (${List.filled(chatIds.length, '?').join(',')})',
          whereArgs: chatIds,
        );

        for (final chatId in chatIds) {
          await _deleteChat(txn, chatId);
        }
      }
    });
  }

  // Helper function to delete a chat completely
  Future<void> _deleteChat(Transaction txn, int chatId) async {
    // Remove from all folders
    await txn.delete(
      'folders_to_chats',
      where: 'chat_id = ?',
      whereArgs: [chatId],
    );

    // Delete messages for that chat
    await txn.delete(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
    );

    // Delete the chat itself
    await txn.delete(
      'chats',
      where: 'id = ?',
      whereArgs: [chatId],
    );

    // Check for and delete orphaned folders
    await _deleteOrphanedFolders(txn);
  }

  Future<void> _deleteOrphanedFolders(Transaction txn) async {
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
    final db = await instance.database;
    final maps = await db.rawQuery('''
    SELECT folders.* FROM folders
    INNER JOIN folders_to_chats ON folders.id = folders_to_chats.folder_id
    WHERE folders_to_chats.chat_id = ?
  ''', [chatId]);
    return maps.map((map) => Folder.fromMap(map)).toList();
  }

  Future<void> updateChatFolders(int chatId, List<int> folderIds) async {
    final db = await instance.database;
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
