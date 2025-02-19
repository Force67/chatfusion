import 'package:monkeychat/database/local_db.dart';
import 'package:monkeychat/models/chat.dart';

class ChatProvider with ChangeNotifier {
  List<Chat> _chats = [];

  List<Chat> get chats => _chats;

  Future<void> loadChats(int? folderId) async {
    final db = LocalDb.instance;
    final chatscol = await db.chats;
    final folderColl = await db.folders;

    if (folderId != null) {
      final chatIds = await folderColl.getChatsInFolder(folderId);
      if (chatIds.isEmpty) {
        _chats = <Chat>[];
        notifyListeners();
        return;
      }
      List<Chat> chats = [];
      for (final chat in chatIds) {
        final cht = await chatscol.getChat(chat.id);
        chats.add(cht);
      }
      _chats = chats;
    } else {
      _chats = await chatscol.getChats();
    }
    notifyListeners();
  }
}
