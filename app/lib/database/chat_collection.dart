import 'package:monkeychat/database/folder_collection.dart';
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

  // Helper function to delete a chat completely
  Future<void> deleteChat(Transaction txn, int chatId) async {
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
    final folderCollection = FolderCollection(db);
    await folderCollection.deleteOrphanedFolders(txn);
  }

  Future<List<int>> findOrphanedChats(Transaction txn) async {
    final orphanedChats = await txn.rawQuery('''
    SELECT chats.id FROM chats
    LEFT JOIN folders_to_chats ON chats.id = folders_to_chats.chat_id
    WHERE folders_to_chats.chat_id IS NULL
  ''');

    return orphanedChats.map((c) => c['id'] as int).toList();
  }

  Future<void> deleteOrphanedChatsAndMessages(
      Transaction txn, List<int> chatIds) async {
    if (chatIds.isEmpty) return;

    // Delete messages associated with orphaned chats
    await txn.delete(
      'messages',
      where: 'chat_id IN (${List.filled(chatIds.length, '?').join(',')})',
      whereArgs: chatIds,
    );

    // Delete orphaned chats
    for (final chatId in chatIds) {
      final chatCollection = ChatCollection(db);
      await chatCollection.deleteChat(txn, chatId);
    }
  }
}
