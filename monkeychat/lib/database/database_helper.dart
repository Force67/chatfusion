import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/llm_model.dart';
import 'dart:convert';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._private();
  static Database? _database;

  DatabaseHelper._private();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'chat_database.db');
    return openDatabase(
      path,
      onCreate: _onCreate,
      version: 1,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE chats(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        model_id TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chat_id INTEGER NOT NULL,
        text TEXT NOT NULL,
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

    print('DBHELPER: Database tables created');
  }

  Future<void> clearAll() async {
    final db = await instance.database;

    // Clear all tables
    await db.delete('chats');
    await db.delete('messages');
    await db.delete('cached_models');

    print('DBHELPER: All data cleared from tables');

    // Close the database
    await db.close();
    _database = null;

    // Delete the database file
    final path = join(await getDatabasesPath(), 'chat_database.db');
    await deleteDatabase(path);

    print('DBHELPER: Database file deleted');
  }

  Future<void> clearChats() async {
    final db = await instance.database;
    await db.delete('chats');
    await db.delete('messages');
    print('DBHELPER: Chats cleared');
  }

  Future<int> insertChat(Chat chat) async {
    final db = await instance.database;
    return db.insert('chats', {
      'title': chat.title,
      'model_id': chat.modelId,
      'created_at': chat.createdAt.toIso8601String(),
    });
  }

  Future<List<LLMModel>> getCachedModels() async {
    final db = await instance.database;
    final maps = await db.query('cached_models');
    return maps.map((map) => LLMModel.fromJson(jsonDecode(map['data'] as String))).toList();
  }

  Future<void> cacheModels(List<LLMModel> models) async {
    final db = await instance.database;
    await db.delete('cached_models');
    for (final model in models) {
      await db.insert('cached_models', {
        'model_id': model.id,
        'data': jsonEncode(model.toJson()),
        'cached_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<int> insertMessage(Message message) async {
    final db = await instance.database;
    return db.insert('messages', {
      'chat_id': message.chatId,
      'text': message.text,
      'is_user': message.isUser ? 1 : 0,
      'created_at': message.createdAt.toIso8601String(),
    });
  }

  Future<List<Chat>> getChats() async {
    final db = await instance.database;
    final maps = await db.query('chats', orderBy: 'created_at DESC');
    return maps.map((map) => Chat.fromMap(map)).toList();
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
}
