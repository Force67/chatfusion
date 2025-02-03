import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/chat_screen.dart';

void main() => runApp(const ChatApp());

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chat',
      theme: darkTheme,
      home: const ChatScreen(),
    );
  }
}
