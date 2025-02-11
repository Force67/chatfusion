import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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
            : Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: _buildContents(text, context),
              ),
      ),
    );
  }

  List<Widget> _buildContents(String text, BuildContext context) {
    final List<Widget> widgets = [];
    final parts = text.split('\n');

    for (final part in parts) {
      if (part.trim().startsWith('```math') && part.trim().endsWith('```')) {
        // Extract math content
        final mathContent = part.replaceAll('```math', '').replaceAll('```', '').trim();
        widgets.add(
          LaTexT(
            laTeXCode: Text(
              '\$$mathContent\$',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      } else if (part.contains(r'`$') && part.contains(r'$`')) {
        // Handle inline math
        final textParts = part.split(RegExp(r'`\$.*?\$`'));
        final mathParts = RegExp(r'`\$(.*?)\$`').allMatches(part);
        
        final List<Widget> rowWidgets = [];
        int mathIndex = 0;
        
        for (int i = 0; i < textParts.length; i++) {
          if (textParts[i].isNotEmpty) {
            rowWidgets.add(
              MarkdownBody(
                selectable: true,
                data: textParts[i],
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(color: Colors.white),
                  a: const TextStyle(color: Colors.blue),
                  em: const TextStyle(fontStyle: FontStyle.italic),
                  strong: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            );
          }
          if (mathIndex < mathParts.length) {
            final mathContent = mathParts.elementAt(mathIndex).group(1);
            rowWidgets.add(
              LaTexT(
                laTeXCode: Text(
                  '\$$mathContent\$',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            );
            mathIndex++;
          }
        }
        
        widgets.add(
          Wrap(
            children: rowWidgets,
          ),
        );
      } else {
        // Regular markdown
        widgets.add(
          MarkdownBody(
            selectable: true,
            data: part,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(color: Colors.white),
              a: const TextStyle(color: Colors.blue),
              em: const TextStyle(fontStyle: FontStyle.italic),
              strong: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    }

    return widgets;
  }
}
