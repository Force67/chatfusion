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
  /// Exports all chats, messages, and attachments for a specific folder to a JSON string.
  Future<String> exportChatsToJson(int folderId) async {
    final folderCollection = await _localDb.folders;
    final messagesCollection = await _localDb.messages;
    final attachmentsCollection = await _localDb.attachments;

    // Fetch chats only in the specified folder
    final chats = await folderCollection.getChatsInFolder(folderId);
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
          if (attachment.filePath != null && attachment.filePath!.isNotEmpty) {
            final file = File(attachment.filePath!);
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

    final uuid = Uuid();

    // Map to store old chat IDs to new chat IDs
    final Map<int, int> chatIdMap = {};

    for (final chatData in exportData) {
      var chat = Chat.fromMap(chatData);
      chat =
          chat.copyWith(id: null, folderId: selectedFolderId); // Reset the ID
      final newChatId = await chatsCollection.insertChat(chat);
      chatIdMap[chatData['id']] = newChatId;

      final messages = chatData['messages'] as List<dynamic>;

      // Map to store old message IDs to new message IDs
      final Map<int, int> messageIdMap = {};

      for (final messageData in messages) {
        var message = Message.fromMap(messageData);
        message = message.copyWith(id: null, chatId: newChatId); // Reset the ID
        final newMessageId = await messagesCollection.insertMessage(message);
        messageIdMap[messageData['id']] = newMessageId;

        final attachments = messageData['attachments'] as List<dynamic>;
        for (final attachmentData in attachments) {
          var attachment = Attachment.fromMap(attachmentData);
          attachment = attachment.copyWith(
            attachmentId: uuid.v4(), // Generate a new unique ID
            messageId: newMessageId,
          );

          // If the attachment is a file, decode the Base64 data and save it to a new file
          if (attachment.filePath != null &&
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
              attachment = attachment.copyWith(filePath: filePath);
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
