import 'package:flutter/material.dart';
import 'package:latext/latext.dart';
import 'package:flutter/services.dart';

class ChatMessage extends StatefulWidget {
  final String text;
  final bool isUser;
  final bool isStreaming;
  final String? reasoning;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isUser,
    this.isStreaming = false,
    this.reasoning,
  });

  @override
  State<ChatMessage> createState() => _ChatMessageState();
}

class _ChatMessageState extends State<ChatMessage> {
  bool _showReasoning = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showCopyMenu(context),
      onSecondaryTap: () => _showCopyMenu(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        alignment: widget.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: widget.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: widget.isUser ? Colors.blueGrey : Colors.grey[800],
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reasoning toggle and content
                  if (!widget.isUser && widget.reasoning != null && widget.reasoning!.isNotEmpty)
                    Column(
                      children: [
                        InkWell(
                          onTap: () => setState(() => _showReasoning = !_showReasoning),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Thinking Process',
                                style: TextStyle(
                                  color: Colors.blue[200],
                                  fontSize: 12,
                                ),
                              ),
                              Icon(
                                _showReasoning ? Icons.expand_less : Icons.expand_more,
                                size: 16,
                                color: Colors.blue[200],
                              ),
                            ],
                          ),
                        ),
                        if (_showReasoning)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: LaTexT(
                              laTeXCode: Text(
                                _convertToLaTeX(widget.reasoning!),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  // Main message content
                  widget.isStreaming
                      ? SelectableText(
                          widget.text,
                          style: const TextStyle(color: Colors.white),
                        )
                      : SelectableRegion(
                          selectionControls: materialTextSelectionControls,
                          focusNode: FocusNode(),
                          child: LaTexT(
                            laTeXCode: Text(
                              _convertToLaTeX(widget.text),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                  const SizedBox(height: 8),
                  // Copy button
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.copy, size: 16, color: Colors.white),
                      onPressed: () => _copyToClipboard(context),
                      tooltip: 'Copy whole message',
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    Clipboard.setData(ClipboardData(text: widget.text));
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
