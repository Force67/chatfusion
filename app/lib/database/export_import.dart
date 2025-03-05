import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:monkeychat/database/local_db.dart';
import 'package:monkeychat/models/attachment.dart';
import 'package:monkeychat/models/chat.dart';
import 'package:monkeychat/models/message.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ExportImport {
  final LocalDb _localDb = LocalDb.instance;

  /// Exports all chats, messages, and attachments to a JSON string.
  Future<String> exportChatsToJson() async {
    final chatsCollection = await _localDb.chats;
    final messagesCollection = await _localDb.messages;
    final attachmentsCollection = await _localDb.attachments;

    if (attachmentsCollection == null) {
      throw Exception('Attachments collection is not initialized');
    }

    final chats = await chatsCollection.getChats();
    List<Map<String, dynamic>> exportData = [];

    for (final chat in chats) {
      final chatMap = chat.toMap();
      final messages = await messagesCollection.getMessages(chat.id);

      List<Map<String, dynamic>> messagesWithAttachments = [];
      for (final message in messages) {
        final messageMap = message.toMap();
        final attachments =
            await attachmentsCollection.getAttachments(message.id);

        List<Map<String, dynamic>> exportedAttachments = [];
        for (final attachment in attachments) {
          final attachmentMap = attachment.toMap();

          // If the attachment is a file, encode its content as Base64
          if (attachment.isFilePath) {
            final file = File(attachment.data);
            if (await file.exists()) {
              final fileBytes = await file.readAsBytes();
              attachmentMap['file_data'] =
                  base64Encode(fileBytes); // Add Base64 data
            } else {
              attachmentMap['file_data'] = ''; // Handle missing files
            }
          }

          exportedAttachments.add(attachmentMap);
        }

        messageMap['attachments'] = exportedAttachments;
        messagesWithAttachments.add(messageMap);
      }

      chatMap['messages'] = messagesWithAttachments;
      exportData.add(chatMap);
    }

    return jsonEncode(exportData);
  }

  /// Imports chats, messages, and attachments from a JSON string.
  Future<void> importChatsFromJson(
      String jsonString, int selectedFolderId) async {
    final exportData = jsonDecode(jsonString) as List<dynamic>;
    final chatsCollection = await _localDb.chats;
    final messagesCollection = await _localDb.messages;
    final attachmentsCollection = await _localDb.attachments;

    if (attachmentsCollection == null) {
      throw Exception('Attachments collection is not initialized');
    }

    final uuid = Uuid();

    for (final chatData in exportData) {
      var chat = Chat.fromMap(chatData);
      chat = chat.copyWith(folderId: selectedFolderId);
      final chatId = await chatsCollection.insertChat(chat);

      final messages = chatData['messages'] as List<dynamic>;
      for (final messageData in messages) {
        var message = Message.fromMap(messageData);
        message = message.copyWith(chatId: chatId);
        final messageId = await messagesCollection.insertMessage(message);

        final attachments = messageData['attachments'] as List<dynamic>;
        for (final attachmentData in attachments) {
          var attachment = Attachment.fromMap(attachmentData);
          attachment = attachment.copyWith(attachmentId: uuid.v4());
          attachment.messageId = messageId;

          // If the attachment is a file, decode the Base64 data and save it to a new file
          if (attachment.isFilePath &&
              attachmentData['file_data'] != null &&
              attachmentData['file_data'].isNotEmpty) {
            try {
              final base64String = attachmentData['file_data'] as String;

              // Validate the Base64 string
              if (base64String.length % 4 != 0) {
                throw FormatException('Invalid Base64 string length');
              }

              final fileBytes = base64Decode(base64String);

              // Save the file to a unique path
              final directory = await getApplicationDocumentsDirectory();
              final filePath =
                  '${directory.path}/attachment_${DateTime.now().millisecondsSinceEpoch}_${attachment.attachmentId}';
              final file = File(filePath);
              await file.writeAsBytes(fileBytes);

              // Update the attachment with the new file path
              attachment = attachment.copyWith(data: filePath);
            } catch (e) {
              debugPrint('Error decoding base64 image: $e');
              debugPrint(
                  'Invalid base64 data for attachment: ${attachment.attachmentId}');
              continue; // Skip this attachment
            }
          }

          await attachmentsCollection.insertAttachment(attachment);
        }
      }
    }
  }
}
