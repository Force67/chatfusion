import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'theme.dart';
import 'screens/chat_screen.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  
  return runApp(const ChatApp());
}



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
