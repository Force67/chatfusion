import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'theme.dart';

import 'screens/chat/chat_screen.dart';
import 'screens/chat/chat_cubit.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'services/model_service.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    // Initialize FFI
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final ModelService modelSvc = ModelService();

  return runApp(
    MultiProvider(
      providers: [
        Provider<ModelService>(create: (context) => modelSvc),
        BlocProvider<ChatCubit>(create: (context) => ChatCubit(modelSvc)),
      ],
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
