import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/chat.dart';
import '../models/message.dart';

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
  }

  Future<int> insertChat(Chat chat) async {
    final db = await instance.database;
    return db.insert('chats', {
      'title': chat.title,
      'created_at': chat.createdAt.toIso8601String(),
    });
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
