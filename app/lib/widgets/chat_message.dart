import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter/services.dart';
import 'package:monkeychat/models/message.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/widgets.dart';
import 'package:markdown/markdown.dart' as md;

class MathTextBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitText(md.Text text, TextStyle? style) {
    final String content = text.text;

    // If no LaTeX-like content, just use regular text
    if (!_containsMathSyntax(content)) {
      return Text(content, style: style);
    }

    // Process and split the text into math and non-math parts
    return _buildRichText(content, style);
  }

  bool _containsMathSyntax(String text) {
    return text.contains(r'\[') || text.contains(r'\]') ||
           text.contains(r'$$') || text.contains(r'$') ||
           text.contains(r'\sum') || text.contains(r'\frac') ||
           text.contains(r'\pi') || text.contains(r'\infty');
  }

  Widget _buildRichText(String content, TextStyle? style) {
    List<InlineSpan> spans = [];

    // Pattern to match LaTeX blocks: \[...\], $...$, $$...$$
    // Also handles common LaTeX commands
    final RegExp mathPattern = RegExp(
      r'(\\\[[\s\S]*?\\\]|\$\$[\s\S]*?\$\$|\$[\s\S]*?\$|\\[a-zA-Z]+(?:_\{.*?\})?(?:\^.*?)?(?:\{.*?\})*)',
      dotAll: true,
    );

    int lastEnd = 0;

    for (var match in mathPattern.allMatches(content)) {
      // Add text before the math expression
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: content.substring(lastEnd, match.start),
          style: style,
        ));
      }

      // Process the math expression
      final mathExpression = match.group(0)!;
      String texContent = mathExpression;

      // Convert from various LaTeX formats to one that Flutter Math can render
      if (texContent.startsWith(r'\[') && texContent.endsWith(r'\]')) {
        texContent = texContent.substring(2, texContent.length - 2);
      } else if (texContent.startsWith(r'$$') && texContent.endsWith(r'$$')) {
        texContent = texContent.substring(2, texContent.length - 2);
      } else if (texContent.startsWith(r'$') && texContent.endsWith(r'$')) {
        texContent = texContent.substring(1, texContent.length - 1);
      }

      spans.add(WidgetSpan(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          color: Colors.transparent, // Ensure transparent background
          child: Math.tex(
            texContent,
            textStyle: style ?? const TextStyle(color: Colors.white),
            mathStyle: _determineMathStyle(mathExpression),
            onErrorFallback: (err) {
              print('LaTeX Error: ${err.message} for $texContent');
              return Text(mathExpression, style: style);
            },
          ),
        ),
        alignment: PlaceholderAlignment.middle,
      ));

      lastEnd = match.end;
    }

    // Add any remaining text
    if (lastEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastEnd),
        style: style,
      ));
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: style,
      ),
    );
  }

  MathStyle _determineMathStyle(String expression) {
    if (expression.startsWith(r'\[') || expression.startsWith(r'$$')) {
      return MathStyle.display;
    }
    return MathStyle.text;
  }

  @override
  bool isBlockElement() => false;

  @override
  void visitElementBefore(md.Element element) {}

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) => null;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => null;
}

// Special handler for display math blocks
class DisplayMathBuilder extends MarkdownElementBuilder {
  @override
  Widget build(BuildContext context, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(child: children.isNotEmpty ? children.first : Container()),
    );
  }

  @override
  Widget? visitText(md.Text text, TextStyle? style) {
    // This handles text content that should be displayed as a math block
    final String content = text.text.trim();

    // Remove any Markdown code block formatting
    String texContent = content;
    if (texContent.startsWith('```') && texContent.endsWith('```')) {
      texContent = texContent.substring(3, texContent.length - 3).trim();
    }

    if (texContent.startsWith(r'\[') && texContent.endsWith(r'\]')) {
      texContent = texContent.substring(2, texContent.length - 2);
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        color: Colors.transparent, // Ensure transparent background
        child: Math.tex(
          texContent,
          textStyle: style ?? const TextStyle(color: Colors.white),
          mathStyle: MathStyle.display,
          onErrorFallback: (err) {
            print('Display LaTeX Error: ${err.message} for $texContent');
            return Text(content, style: style);
          },
        ),
      ),
    );
  }

  @override
  bool isBlockElement() => true;

  @override
  void visitElementBefore(md.Element element) {}

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) => null;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) => null;
}

String parseEmojis(String text) {
  final emojiMap = {
    ':smile:': '😊',
    ':grin:': '😁',
    ':laughing:': '😆',
    ':wink:': '😉',
    ':heart:': '❤️',
    ':thumbsup:': '👍',
    ':rocket:': '🚀',
  };

  String result = text;
  emojiMap.forEach((key, value) {
    result = result.replaceAll(key, value);
  });
  return result;
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

  // Preprocess text to standardize math notation and prepare for rendering
  String _preprocessText(String text) {
    // Handle emoji
    String processed = parseEmojis(text);

    // Process display math environments
    processed = _preprocessDisplayMath(processed);

    // Standardize LaTeX commands
    processed = processed
        .replaceAll('\\+fraction', '\\frac')
        .replaceAll('\\+sqrt', '\\sqrt')
        .replaceAll('\\+frac', '\\frac')
        .replaceAll('\\+sum', '\\sum')
        .replaceAll('\\+int', '\\int')
        .replaceAll('\\+alpha', '\\alpha')
        .replaceAll('\\+beta', '\\beta')
        .replaceAll('\\+gamma', '\\gamma')
        .replaceAll('\\+delta', '\\delta')
        .replaceAll('\\+text', '\\text');

    return processed;
  }

  // Process display math environments - convert to Markdown code blocks
  // so they can be handled by a specific builder
  String _preprocessDisplayMath(String text) {
    // Convert \[ ... \] to ```math ... ``` for special handling
    // This makes it easy to identify display math in the Markdown renderer
    return text.replaceAllMapped(
      RegExp(r'\\\[([\s\S]*?)\\\]', dotAll: true),
      (match) => '\n```math\n${match.group(1)}\n```\n'
    );
  }

  @override
  Widget build(BuildContext context) {
    // Create custom Markdown renderers
    final Map<String, MarkdownElementBuilder> builders = {
      'p': MathTextBuilder(),
      'text': MathTextBuilder(),
      'code': MathTextBuilder(),
      // Special handling for code blocks that contain math
      'pre': DisplayMathBuilder(),
    };

    String processedText = _preprocessText(widget.text);
    String? processedReasoning =
        widget.reasoning != null ? _preprocessText(widget.reasoning!) : null;

    final markdownStyleSheet = MarkdownStyleSheet.fromTheme(Theme.of(context))
        .copyWith(
      p: GoogleFonts.roboto(color: Colors.white),
      a: GoogleFonts.roboto(color: Colors.lightBlueAccent),
      code: GoogleFonts.robotoMono(color: Colors.yellowAccent),
      h1: GoogleFonts.roboto(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      h2: GoogleFonts.roboto(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      blockSpacing: 8.0,
      codeblockPadding: EdgeInsets.all(8.0),
      codeblockDecoration: BoxDecoration(
        color: Colors.transparent, // Make code block backgrounds transparent
        borderRadius: BorderRadius.circular(4.0),
      ),
    );

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
              child: Theme(
                // Provide a theme with transparent canvas color for all child widgets
                data: Theme.of(context).copyWith(
                  canvasColor: Colors.transparent,
                  cardColor: Colors.transparent,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.isUser &&
                        processedReasoning != null &&
                        processedReasoning.isNotEmpty)
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
                                data: processedReasoning,
                                styleSheet: markdownStyleSheet.copyWith(
                                  p: GoogleFonts.roboto(
                                      color: Colors.white70, fontSize: 12),
                                ),
                                builders: builders,
                              ),
                            ),
                        ],
                      ),
                    widget.isStreaming
                        ? SelectableText(
                            processedText,
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                            ),
                          )
                        : MarkdownBody(
                            data: processedText,
                            styleSheet: markdownStyleSheet,
                            builders: builders,
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
