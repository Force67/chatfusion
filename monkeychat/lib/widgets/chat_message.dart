import 'package:flutter/material.dart';
import 'package:latext/latext.dart';
import 'package:flutter/services.dart'; // For Clipboard

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
    return GestureDetector(
      onLongPress: () => _showCopyMenu(context),
      onSecondaryTap: () => _showCopyMenu(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: isUser ? Colors.blueGrey : Colors.grey[800],
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: isStreaming
                    ? SelectableText(
                        text,
                        style: const TextStyle(color: Colors.white),
                      )
                    : SelectableRegion(
                        selectionControls: materialTextSelectionControls,
                        focusNode: FocusNode(),
                        child: LaTexT(
                          laTeXCode: Text(
                            _convertToLaTeX(text),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 8), // Add spacing between text and button
              IconButton(
                icon: const Icon(Icons.copy, size: 16, color: Colors.white),
                onPressed: () => _copyToClipboard(context),
                tooltip: 'Copy whole message', // Tooltip for better UX
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCopyMenu(BuildContext context) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RenderBox textBox = context.findRenderObject() as RenderBox;
    final Offset position = textBox.localToGlobal(Offset.zero, ancestor: overlay);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + textBox.size.width,
        position.dy + textBox.size.height,
      ),
      items: [
        PopupMenuItem(
          child: const Text('Copy Whole Message'),
          onTap: () => _copyToClipboard(context),
        ),
      ],
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message copied to clipboard')),
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
