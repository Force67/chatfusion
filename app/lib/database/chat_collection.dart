import 'package:monkeychat/models/chat.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';

class ChatCollection {
  final Database db;

  ChatCollection(this.db);

  Future<int> insertChat(Chat chat) async {
    try {
      return await db.insert('chats', {
        'title': chat.title,
        'model_id': chat.modelId,
        'created_at': chat.createdAt.toIso8601String(),
        'params': jsonEncode(chat.modelSettings),
      });
    } catch (e) {
      print('Error inserting chat: $e');
      return -1; // Or throw an exception
    }
  }

  Future<bool> updateParams(int chatId, Map<String, dynamic> params) async {
    try {
      final result = await db.update(
        'chats',
        {'params': jsonEncode(params)},
        where: 'id = ?',
        whereArgs: [chatId],
      );
      return result > 0;
    } catch (e) {
      print('Error updating chat params: $e');
      return false; // Or throw an exception
    }
  }

  Future<List<Chat>> getChats() async {
    try {
      final maps = await db.query('chats', orderBy: 'created_at DESC');
      return maps.map((map) => Chat.fromMap(map)).toList();
    } catch (e) {
      print('Error getting chats: $e');
      return []; // Or throw an exception
    }
  }

  Future<Chat> getChat(int chatId) async {
    try {
      final maps = await db.query(
        'chats',
        where: 'id = ?',
        whereArgs: [chatId],
      );
      return Chat.fromMap(maps.first);
    } catch (e) {
      print("error getting chat: $e");
      rethrow;
    }
  }
}
