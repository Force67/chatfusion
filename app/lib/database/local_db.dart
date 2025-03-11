import 'package:flutter/foundation.dart';
import 'package:monkeychat/database/attachments_collection.dart';
import 'package:monkeychat/database/folder_collection.dart';
import 'package:monkeychat/database/message_collection.dart';
import 'package:monkeychat/models/folder.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/llm.dart';
import 'dart:convert';
import 'chat_collection.dart';

class LocalDb {
  static final LocalDb instance = LocalDb._private();
  static Database? _database;
  static const int _version = 5; // Incremented version for schema changes

  Database? _cachedDb;
  ChatCollection? _chatCollection;
  FolderCollection? _folderCollection;
  MessageCollection? _messageCollection;
  AttachmentsCollection? _attachmentsCollection;

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

  Future<MessageCollection> get messages async {
    final db = _cachedDb ?? await database;
    _messageCollection ??= MessageCollection(db);
    return _messageCollection!;
  }

  Future<FolderCollection> get folders async {
    final db = _cachedDb ?? await database;
    _folderCollection ??= FolderCollection(db);
    return _folderCollection!;
  }

  Future<AttachmentsCollection> get attachments async {
    final db = _cachedDb ?? await database;
    _attachmentsCollection ??= AttachmentsCollection(db);
    return _attachmentsCollection!;
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
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE folders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parent_id INTEGER,
        name TEXT NOT NULL,
        hashed_password TEXT, -- May be null, salted and encrypted,
        color_code TEXT NOT NULL, -- Hex color code
        created_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE chats(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        folder_id INTEGER NOT NULL,
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
        type INTEGER NOT NULL,
        text TEXT NOT NULL,
        reasoning TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY(chat_id) REFERENCES chats(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE attachments (
        attachment_id TEXT PRIMARY KEY,
        message_id INTEGER NOT NULL,
        mime_type TEXT NOT NULL,
        file_path TEXT, -- Path to the file (if stored as a file)
        file_data TEXT, -- Base64-encoded data (if stored as text)
        created_at TEXT NOT NULL,
        FOREIGN KEY (message_id) REFERENCES messages(id)
      );
    ''');

    // This app supports having multiple platforms for the ai inference.
    // For instance, Openrouter and ollama. This table encodes the configured
    // providers with numeric ids.
    await db.execute('''
      CREATE TABLE model_platforms(
        provider_id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        shorthand TEXT NOT NULL,
        cached_at TEXT NOT NULL
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
      print("Created database tables");
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 5) {
      // Migration to version 5
      await db.execute('DROP TABLE IF EXISTS attachments');
      await db.execute('''
        CREATE TABLE attachments (
          attachment_id TEXT PRIMARY KEY,
          message_id INTEGER NOT NULL,
          mime_type TEXT NOT NULL,
          file_path TEXT, -- Path to the file (if stored as a file)
          file_data TEXT, -- Base64-encoded data (if stored as text)
          created_at TEXT NOT NULL,
          FOREIGN KEY (message_id) REFERENCES messages(id)
        );
      ''');
    }

    if (oldVersion < 4) {
      await db.execute('ALTER TABLE attachments ADD COLUMN file_data TEXT');
    }

    if (oldVersion < 3) {
      await db.execute('DROP TABLE IF EXISTS folders');
      await db.execute('''
        CREATE TABLE folders(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          created_at TEXT NOT NULL
        );
      ''');
    }
  }

  Future<void> clearAll({bool deleteFolders = true}) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('chats');
      await txn.delete('messages');
      await txn.delete('cached_models');

      if (deleteFolders) {
        await txn.delete('folders');
      }
    });
  }

  Future<void> clearChats() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('chats');
      await txn.delete('messages');
    });
  }

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
