import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/llm.dart';
import 'dart:convert';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._private();
  static Database? _database;
  static const int _version = 2; // Updated version

  DatabaseHelper._private();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'chat_database.db');
    if (kDebugMode) {
      print('Database path: $path');
    }
    return openDatabase(
      path,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      version: _version,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE chats(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        model_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        params TEXT NOT NULL
      )
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
      )
    ''');

    await db.execute('''
      CREATE TABLE cached_models(
        model_id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');
    print("CREATED THE DB");
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add params column to existing chats table
      await db.execute('''
        ALTER TABLE chats 
        ADD COLUMN params TEXT NOT NULL DEFAULT '{}'
      ''');
    }
  }

  Future<int> insertChat(Chat chat) async {
    final db = await instance.database;
    return db.insert('chats', {
      'title': chat.title,
      'model_id': chat.modelId,
      'created_at': chat.createdAt.toIso8601String(),
      'params': jsonEncode(chat.modelSettings),
    });
  }

  Future<List<Chat>> getChats() async {
    final db = await instance.database;
    final maps = await db.query('chats', orderBy: 'created_at DESC');
    return maps.map((map) => Chat.fromMap(map)).toList();
  }

  // Updated clear methods to handle schema changes
  Future<void> clearAll() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('chats');
      await txn.delete('messages');
      await txn.delete('cached_models');
    });
  }

  Future<void> clearChats() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('chats');
      await txn.delete('messages');
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

  Future<Chat> getChat(int chatId) async {
    final db = await instance.database;
    final maps = await db.query(
      'chats',
      where: 'id = ?',
      whereArgs: [chatId],
    );
    return Chat.fromMap(maps.first);
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
