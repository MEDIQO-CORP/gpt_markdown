part of 'gpt_markdown.dart';

/// Controller used by [GptMarkdownEditor] to manage the current text and
/// provide utilities for animated appends.
class GptMarkdownController extends ChangeNotifier {
  GptMarkdownController({String text = ''})
      : _textController = _MarkdownEditingController(text: text) {
    _textController.addListener(notifyListeners);
  }

  final _MarkdownEditingController _textController;

  /// Exposes the underlying [TextEditingController].
  TextEditingController get textController => _textController;

  /// Notifies when a typewriter append is running.
  final ValueNotifier<bool> isAppending = ValueNotifier<bool>(false);

  /// Current markdown text.
  String get text => _textController.text;

  set text(String value) {
    if (_textController.text != value) {
      _textController.text = value;
    }
  }

  /// Appends [chunk] to the end of the document using a typewriter effect.
  Future<void> appendMarkdown(String chunk,
      {Duration charDelay = const Duration(milliseconds: 40)}) async {
    if (chunk.isEmpty) return;
    isAppending.value = true;
    for (var i = 0; i < chunk.length; i++) {
      _textController.text += chunk[i];
      await Future.delayed(charDelay);
    }
    isAppending.value = false;
  }

  @override
  void dispose() {
    _textController.dispose();
    isAppending.dispose();
    super.dispose();
  }
}

/// A markdown-aware [TextEditingController] that renders the current value as
/// rich text and applies a gradient shader to the last few words.
class _MarkdownEditingController extends TextEditingController {
  _MarkdownEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    bool withComposing = false,
  }) {
    final baseStyle = style ?? const TextStyle();
    // First, parse the raw markdown into styled spans without gradient.
    final spans = _parseMarkdown(text, baseStyle);

    // Compute where the gradient should start in the plain string.
    final plainText = spans.map((s) => s.text ?? '').join();
    final wordMatches = RegExp(r'\b\w+\b').allMatches(plainText).toList();
    if (wordMatches.isEmpty) {
      return TextSpan(children: spans, style: baseStyle);
    }
    int count = 3;
    if (wordMatches.length < 3 && wordMatches.length >= 2) {
      count = 2;
    } else if (wordMatches.length < 2) {
      count = wordMatches.length;
    }
    final startMatch = wordMatches[wordMatches.length - count];
    final highlightStart = startMatch.start;

    // Split spans to apply gradient starting at [highlightStart].
    final result = <InlineSpan>[];
    int index = 0;
    for (final span in spans) {
      final text = span.text ?? '';
      if (text.isEmpty) {
        result.add(span);
        continue;
      }
      final end = index + text.length;
      if (end <= highlightStart) {
        // Entire span before highlight.
        result.add(span);
      } else if (index >= highlightStart) {
        // Entire span within highlight.
        result.add(_applyGradient(span, baseStyle));
      } else {
        // Span splits at highlight.
        final before = text.substring(0, highlightStart - index);
        final after = text.substring(highlightStart - index);
        result.add(TextSpan(text: before, style: span.style));
        result.add(_applyGradient(TextSpan(text: after, style: span.style), baseStyle));
      }
      index = end;
    }

    return TextSpan(style: baseStyle, children: result);
  }

  /// Parses a very small subset of markdown (**bold**, *italic*, `code`).
  List<TextSpan> _parseMarkdown(String input, TextStyle baseStyle) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(\*\*.*?\*\*|\*.*?\*|`.*?`)', dotAll: true);
    int index = 0;
    for (final match in regex.allMatches(input)) {
      if (match.start > index) {
        spans.add(TextSpan(
            text: input.substring(index, match.start), style: baseStyle));
      }
      final matchText = match.group(0)!;
      if (matchText.startsWith('**')) {
        spans.add(TextSpan(
            text: matchText.substring(2, matchText.length - 2),
            style: baseStyle.copyWith(fontWeight: FontWeight.bold)));
      } else if (matchText.startsWith('*')) {
        spans.add(TextSpan(
            text: matchText.substring(1, matchText.length - 1),
            style: baseStyle.copyWith(fontStyle: FontStyle.italic)));
      } else if (matchText.startsWith('`')) {
        spans.add(TextSpan(
            text: matchText.substring(1, matchText.length - 1),
            style: baseStyle.copyWith(fontFamily: 'monospace')));
      }
      index = match.end;
    }
    if (index < input.length) {
      spans.add(TextSpan(text: input.substring(index), style: baseStyle));
    }
    return spans;
  }

  InlineSpan _applyGradient(TextSpan span, TextStyle baseStyle) {
    final painter = TextPainter(
      text: TextSpan(text: span.text, style: span.style ?? baseStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color.fromRGBO(119, 49, 216, 1),
          Color.fromRGBO(241, 111, 99, 1),
          Color.fromRGBO(205, 31, 134, 1),
        ],
      ).createShader(
        Rect.fromLTWH(0, 0, max(painter.width, 1), painter.height),
      );
    return TextSpan(
      text: span.text,
      style: (span.style ?? baseStyle).copyWith(foreground: paint),
    );
  }
}

/// A markdown editor that displays rendered markdown, applies a gradient to the
/// last few words, and can animate appended text chunks.
class GptMarkdownEditor extends StatefulWidget {
  const GptMarkdownEditor({
    super.key,
    required this.controller,
    this.onChanged,
  });

  final GptMarkdownController controller;
  final ValueChanged<String>? onChanged;

  @override
  State<GptMarkdownEditor> createState() => _GptMarkdownEditorState();
}

class _GptMarkdownEditorState extends State<GptMarkdownEditor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
          ..value = 1;
    widget.controller.addListener(_handleChange);
    widget.controller.isAppending.addListener(_handleAppend);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChange);
    widget.controller.isAppending.removeListener(_handleAppend);
    _fadeController.dispose();
    super.dispose();
  }

  void _handleChange() {
    widget.onChanged?.call(widget.controller.text);
    setState(() {});
  }

  void _handleAppend() {
    if (widget.controller.isAppending.value) {
      _fadeController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodyMedium;

    return FadeTransition(
      opacity: _fadeController.drive(Tween(begin: 0.0, end: 1.0)),
      child: TextField(
        controller: widget.controller.textController,
        maxLines: null,
        style: baseStyle,
        decoration: const InputDecoration(
          border: InputBorder.none,
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}

