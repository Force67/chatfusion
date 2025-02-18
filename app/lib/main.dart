import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter/material.dart';
import 'theme.dart';

import 'screens/chat/chat_screen.dart';
import 'screens/chat/chat_cubit.dart';



import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future main() async {
  if (Platform.isWindows || Platform.isLinux) {
    // Initialize FFI
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  return runApp(
      BlocProvider(
        create: (context) => ChatCubit(

        ),
        child: const ChatApp(),
      ),
    );
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
