import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:latext/latext.dart';
import 'package:flutter/services.dart';
import 'package:monkeychat/models/message.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/widgets.dart';
import 'package:markdown/markdown.dart' as md;

// Custom Renderer for handling LaTeX placeholders
class LatexRenderer extends MarkdownElementBuilder {
  final Map<String, String> latexPlaceholders;

  LatexRenderer({required this.latexPlaceholders});

  @override
  Widget visitText(md.Text text, TextStyle? style) {
    String content = text.text ?? '';
    List<Widget> inlineWidgets = [];
    List<String> placeholders = latexPlaceholders.keys.toList();

    if (placeholders.isEmpty) {
      return Text(content, style: style);
    }

    // Create regex pattern to match all placeholders
    String pattern = placeholders.map((p) => RegExp.escape(p)).join('|');
    RegExp regex = RegExp(pattern);

    List<String> parts = [];
    int lastIndex = 0;

    // Split content into parts using placeholders
    for (var match in regex.allMatches(content)) {
      if (match.start > lastIndex) {
        parts.add(content.substring(lastIndex, match.start));
      }
      parts.add(match.group(0)!);
      lastIndex = match.end;
    }

    if (lastIndex < content.length) {
      parts.add(content.substring(lastIndex));
    }

    // Build widgets for each part
    for (String part in parts) {
      if (latexPlaceholders.containsKey(part)) {
        String latex = latexPlaceholders[part]!;
        inlineWidgets.add(Container(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Math.tex(
            latex,
            mathStyle: MathStyle.display,
            textStyle: style?.copyWith(
              fontFamily: 'MathJax',
              fontSize: 14,
            ),
            onErrorFallback: (error) => Text(error.message, style: style),
          ),
        ));
      } else {
        inlineWidgets.add(Text(part, style: style));
      }
    }

    return Wrap(children: inlineWidgets);
  }
}

class ChatMessage extends StatefulWidget {
  final String text;
  final bool isUser;
  final bool isStreaming;
  final String? reasoning;
  final VoidCallback? onRetry;
  final List<Attachment> attachments;

  const ChatMessage({
    super.key,
    required this.text,
    required this.isUser,
    this.isStreaming = false,
    this.reasoning,
    this.onRetry,
    this.attachments = const [],
  });

  @override
  State<ChatMessage> createState() => _ChatMessageState();
}

class _ChatMessageState extends State<ChatMessage> {
  late bool _showReasoning;
  final Map<String, String> _latexPlaceholders = {};

  @override
  void initState() {
    super.initState();
    _showReasoning = widget.isStreaming && widget.reasoning?.isNotEmpty == true;
  }

  Widget _buildAttachmentDisplay(BuildContext context, Attachment attachment) {
    if (attachment.mimeType.startsWith('image/')) {
      Widget imageWidget;
      if (attachment.isFilePath) {
        imageWidget = Image.file(File(attachment.data));
      } else {
        try {
          final decodedBytes = base64Decode(attachment.data);
          imageWidget = Image.memory(decodedBytes);
        } catch (e) {
          print("Error decoding base64 image: $e");
          return const Text("Error displaying image");
        }
      }

      return Padding(
        padding: const EdgeInsets.only(right: 4.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 80,
              maxHeight: 80,
            ),
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: FittedBox(
                fit: BoxFit.cover,
                child: imageWidget,
              ),
            ),
          ),
        ),
      );
    } else {
      return const Icon(Icons.attach_file);
    }
  }

  String _preProcessMarkdown(String markdown) {
    _latexPlaceholders.clear();
    int placeholderCount = 0;

    // Modified regex with better capture groups
    final regex = RegExp(
      r'(?<!\\)(?:\\\\)*(\$\$?)(?!\$)((?:\\[^\$]|[^\$])+?)\1',
      multiLine: true,
    );

    return markdown.replaceAllMapped(regex, (match) {
      placeholderCount++;
      final placeholder = 'LATEX_PLACEHOLDER_$placeholderCount';
      final delimiter = match.group(1)!;
      final content = match.group(2)!;

      // Preserve original LaTeX with proper escaping
      _latexPlaceholders[placeholder] = '\\$delimiter$content\\$delimiter';

      return placeholder;
    });
  }

  @override
  Widget build(BuildContext context) {
    final renderers = {
      'text': LatexRenderer(latexPlaceholders: _latexPlaceholders),
    };
    return GestureDetector(
      onLongPress: () => _showCopyMenu(context),
      onSecondaryTap: () => _showCopyMenu(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        alignment: widget.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              widget.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.isUser
                      ? [
                          Colors.lightBlue.shade300,
                          Colors.blue.shade800,
                        ]
                      : [
                          Colors.purple.shade400,
                          Colors.indigo.shade800,
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12.0),
              ),
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.isUser &&
                      widget.reasoning != null &&
                      widget.reasoning!.isNotEmpty)
                    Column(
                      children: [
                        InkWell(
                          onTap: () =>
                              setState(() => _showReasoning = !_showReasoning),
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
                                _showReasoning
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 16,
                                color: Colors.blue[200],
                              ),
                            ],
                          ),
                        ),
                        if (_showReasoning || widget.isStreaming)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: MarkdownBody(
                              // Use MarkdownBody for reasoning too!
                              data: _preProcessMarkdown(widget.reasoning!),
                              styleSheet: MarkdownStyleSheet.fromTheme(
                                      Theme.of(context))
                                  .copyWith(
                                p: GoogleFonts.roboto(
                                    color: Colors.white70, fontSize: 12),
                              ),
                              builders: renderers,
                            ),
                          ),
                      ],
                    ),
                  widget.isStreaming
                      ? SelectableText(
                          widget.text,
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                          ),
                        )
                      : MarkdownBody(
                          data: _preProcessMarkdown(widget.text),
                          styleSheet:
                              MarkdownStyleSheet.fromTheme(Theme.of(context))
                                  .copyWith(
                            p: GoogleFonts.roboto(color: Colors.white),
                            a: GoogleFonts.roboto(
                                color: Colors.lightBlueAccent),
                            code: GoogleFonts.robotoMono(
                                color: Colors.yellowAccent),
                            h1: GoogleFonts.roboto(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold),
                            h2: GoogleFonts.roboto(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                          builders: renderers,
                        ),
                  const SizedBox(height: 4),
                  if (widget.attachments.isNotEmpty)
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.attachments.length,
                        itemBuilder: (context, index) {
                          return _buildAttachmentDisplay(
                              context, widget.attachments[index]);
                        },
                      ),
                    ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!widget.isUser && widget.onRetry != null)
                          IconButton(
                            icon: const Icon(Icons.refresh,
                                size: 10, color: Colors.white),
                            onPressed: widget.onRetry,
                            tooltip: 'Retry',
                          ),
                        IconButton(
                          icon: const Icon(Icons.copy,
                              size: 10, color: Colors.white),
                          onPressed: () => _copyToClipboard(context),
                          tooltip: 'Copy whole message',
                        ),
                      ],
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
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RenderBox textBox = context.findRenderObject() as RenderBox;
    final Offset position =
        textBox.localToGlobal(Offset.zero, ancestor: overlay);

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
}
