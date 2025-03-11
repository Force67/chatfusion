import 'package:monkeychat/models/message.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'dart:io'; // For File operations
import 'dart:convert'; // For Base64
import 'package:mime/mime.dart';

class MessageCollection {
  final Database db;

  MessageCollection(this.db);

  Future<int> insertMessage(Message message,
      {List<File>? attachmentFiles}) async {
    return db.transaction((txn) async {
      final messageId = await txn.insert('messages', {
        'chat_id': message.chatId,
        'type': message.type.index,
        'text': message.text,
        'reasoning': message.reasoning,
        'created_at': message.createdAt.toIso8601String(),
      });

      if (attachmentFiles != null && attachmentFiles.isNotEmpty) {
        for (var attachmentFile in attachmentFiles) {
          var uuid = const Uuid();
          String attachmentId = uuid.v4();
          final mimeType = lookupMimeType(attachmentFile.path);

          String? filePath;
          String? fileData;

          if (attachmentFile.lengthSync() < 1024 * 100) {
            // < 100KB, store data as Base64 in file_data
            List<int> bytes = await attachmentFile.readAsBytes();
            fileData = base64Encode(bytes);
          } else {
            // Store file path in file_path
            filePath = attachmentFile.path;
          }

          await txn.insert('attachments', {
            'attachment_id': attachmentId,
            'message_id': messageId,
            'mime_type': mimeType,
            'file_path': filePath,
            'file_data': fileData,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }
      return messageId;
    });
  }

  Future<void> deleteMessage(int messageId) async {
    await db.transaction((txn) async {
      // Delete associated attachments first (if any)
      List<Map<String, dynamic>> attachments = await txn.query(
        'attachments',
        where: 'message_id = ?',
        whereArgs: [messageId],
      );

      for (var attachment in attachments) {
        if (attachment['file_path'] != null) {
          // Optionally delete the file at file_path if it exists
          /*
          File attachmentFile = File(attachment['file_path']);
          attachmentFile.delete();
          */
        }
        await txn.delete(
          'attachments',
          where: 'attachment_id = ? AND message_id = ?',
          whereArgs: [attachment['attachment_id'], messageId],
        );
      }

      // Now delete the message
      await txn.delete(
        'messages',
        where: 'id = ?',
        whereArgs: [messageId],
      );
    });
  }

  Future<List<Message>> getMessages(int chatId) async {
    final maps = await db.rawQuery('''
      SELECT 
        m.*,
        GROUP_CONCAT(a.attachment_id) AS attachment_ids,
        GROUP_CONCAT(a.mime_type) AS mime_types,
        GROUP_CONCAT(a.file_path) AS file_paths,
        GROUP_CONCAT(a.file_data) AS file_data
      FROM messages m
      LEFT JOIN attachments a ON m.id = a.message_id
      WHERE m.chat_id = ?
      GROUP BY m.id
      ORDER BY m.created_at
    ''', [chatId]);

    return maps.map((map) {
      return Message.fromMapWithAttachments(map, messageId: chatId);
    }).toList();
  }
}
