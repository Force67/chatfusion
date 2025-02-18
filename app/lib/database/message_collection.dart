import 'package:monkeychat/models/message.dart';
import 'package:sqflite/sqflite.dart';

class MessageCollection {
  final Database db;

  MessageCollection(this.db);

  Future<int> insertMessage(Message message) async {
    return db.insert('messages', {
      'chat_id': message.chatId,
      'text': message.text,
      'reasoning': message.reasoning,
      'is_user': message.isUser ? 1 : 0,
      'created_at': message.createdAt.toIso8601String(),
    });
  }

  Future<void> deleteMessage(int messageId) async {
    await db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<List<Message>> getMessages(int chatId) async {
    final maps = await db.query(
      'messages',
      where: 'chat_id = ?',
      whereArgs: [chatId],
      orderBy: 'created_at',
    );
    return maps.map((map) => Message.fromMap(map)).toList();
  }
}
