import 'package:monkeychat/models/attachment.dart';
import 'package:sqflite/sqflite.dart';

class AttachmentsCollection {
  final Database db;

  AttachmentsCollection(this.db);

  // Add methods for interacting with the attachments table
  Future<List<Attachment>> getAttachments(int messageId) async {
    final List<Map<String, dynamic>> maps = await db.query(
      'attachments',
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
    return maps.map((map) => Attachment.fromMap(map)).toList();
  }

  Future<void> insertAttachment(Attachment attachment) async {
    await db.insert(
      'attachments',
      {
        ...attachment.toMap(),
        'created_at': DateTime.now().toIso8601String(), // Add created_at
      },
    );
  }

  Future<void> deleteAttachmentsForMessage(int messageId) async {
    await db.delete(
      'attachments',
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }
}
