import 'package:flutter/material.dart';
import 'package:latext/latext.dart';

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isStreaming;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isUser,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: isUser ? Colors.blueGrey : Colors.grey[800],
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: isStreaming
            ? Text(
                text,
                style: const TextStyle(color: Colors.white),
              )
            : LaTexT(
                laTeXCode: Text(
                  _convertToLaTeX(text),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
      ),
    );
  }

  String _convertToLaTeX(String text) {
    // Convert markdown to LaTeX text formatting
    String result = text;
    
    // Convert bold
    result = result.replaceAllMapped(
      RegExp(r'\*\*(.*?)\*\*'),
      (match) => '\\textbf{${match[1]}}',
    );
    
    // Convert italic
    result = result.replaceAllMapped(
      RegExp(r'\*(.*?)\*'),
      (match) => '\\textit{${match[1]}}',
    );

    // Handle mathematical expressions
    result = result.replaceAllMapped(
      RegExp(r'(\d+\s*[\+\-\*\/×÷=]\s*\d+)|(\\\w+{.*?})|(\^{.*?})|(\${.*?}\$)'),
      (match) => '\$${match[0]}\$',
    );

    return result;
  }
}
