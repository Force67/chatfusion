import 'package:flutter/foundation.dart';
import 'package:monkeychat/models/attachment.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io'; // For file operations

class AttachmentsCollection {
  final Database db;

  AttachmentsCollection(this.db);

  /// Retrieves all attachments for a specific message.
  Future<List<Attachment>> getAttachments(int messageId) async {
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'attachments',
        columns: [
          'attachment_id',
          'message_id',
          'mime_type',
          'file_path',
          'file_data',
          'created_at',
        ],
        where: 'message_id = ?',
        whereArgs: [messageId],
      );

      return maps.map((map) => Attachment.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error fetching attachments: $e');
      rethrow;
    }
  }

  /// Inserts an attachment into the database.
  Future<void> insertAttachment(Attachment attachment) async {
    try {
      await db.insert(
        'attachments',
        {
          'attachment_id': attachment.attachmentId,
          'message_id': attachment.messageId,
          'mime_type': attachment.mimeType,
          'file_path': attachment.filePath,
          'file_data': attachment.fileData,
          'created_at': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Error inserting attachment: $e');
      rethrow;
    }
  }

  /// Deletes all attachments associated with a specific message.
  Future<void> deleteAttachmentsForMessage(int messageId) async {
    try {
      // Fetch attachments to delete associated files (if needed)
      final attachments = await getAttachments(messageId);
      for (final attachment in attachments) {
        if (attachment.filePath != null && attachment.filePath!.isNotEmpty) {
          // Delete the file from the file system
          final file = File(attachment.filePath!);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }

      // Delete the attachments from the database
      await db.delete(
        'attachments',
        where: 'message_id = ?',
        whereArgs: [messageId],
      );
    } catch (e) {
      debugPrint('Error deleting attachments: $e');
      rethrow;
    }
  }

  /// Updates an existing attachment.
  Future<void> updateAttachment(Attachment attachment) async {
    try {
      await db.update(
        'attachments',
        attachment.toMap(),
        where: 'attachment_id = ?',
        whereArgs: [attachment.attachmentId],
      );
    } catch (e) {
      debugPrint('Error updating attachment: $e');
      rethrow;
    }
  }
}
