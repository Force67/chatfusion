import 'package:flutter/foundation.dart';
import 'package:monkeychat/database/folder_collection.dart';
import 'package:monkeychat/database/message_collection.dart';
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
  FolderCollection? _folderCollection;
  MessageCollection? _messageCollection;

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

  Future<FolderCollection> get folders async {
    final db = _cachedDb ?? await database;
    _folderCollection ??= FolderCollection(db);
    return _folderCollection!;
  }

  Future<MessageCollection> get messages async {
    final db = _cachedDb ?? await database;
    _messageCollection ??= MessageCollection(db);
    return _messageCollection!;
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
}
