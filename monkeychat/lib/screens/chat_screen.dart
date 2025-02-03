import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../widgets/chat_message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  late int _currentChatId;
  bool _isNewChat = true;

  Future<List<Chat>> _loadChats() async {
    return await DatabaseHelper.instance.getChats();
  }

  Future<void> _createNewChat() async {
    final newChat = Chat(
      id: 0,
      title: 'New Chat',
      createdAt: DateTime.now(),
    );
    _currentChatId = await DatabaseHelper.instance.insertChat(newChat);
    setState(() => _isNewChat = true);
  }

  void _handleSubmitted(String text) async {
    _textController.clear();

    // Create new chat if it's the first message
    if (_isNewChat) {
      await _createNewChat();
      _isNewChat = false;
    }

    final userMessage = Message(
      id: 0,
      chatId: _currentChatId,
      text: text,
      isUser: true,
      createdAt: DateTime.now(),
    );
    await DatabaseHelper.instance.insertMessage(userMessage);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chat Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      drawer: Drawer(
        child: FutureBuilder<List<Chat>>(
          future: _loadChats(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            final chats = snapshot.data!;
            return Column(
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Chat',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('New Chat'),
                        onPressed: _createNewChat,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: chats.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: const Icon(Icons.chat_bubble_outline),
                        title: Text(chats[index].title),
                        onTap: () {
                          setState(() {
                            _currentChatId = chats[index].id;
                            _isNewChat = false;
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: FutureBuilder<List<Message>>(
        future: _isNewChat ? Future.value([]) : DatabaseHelper.instance.getMessages(_currentChatId),
        builder: (context, snapshot) {
          final messages = snapshot.data ?? [];

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages.reversed.toList()[index];
                    return ChatMessage(
                      text: message.text,
                      isUser: message.isUser,
                    );
                  },
                ),
              ),
              _buildInput(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.grey[850],
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type your message...',
                hintStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20.0),
              ),
              onSubmitted: _handleSubmitted,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.blueGrey),
            onPressed: () => _handleSubmitted(_textController.text),
          ),
        ],
      ),
    );
  }
}
