part of 'gpt_markdown.dart';

/// Controller used by [GptMarkdownEditor] to manage the current text and
/// provide utilities for animated appends.
class GptMarkdownController extends ChangeNotifier {
  GptMarkdownController({String text = ''})
      : _textController = _MarkdownEditingController(text: text) {
    _textController.addListener(() {
      notifyListeners();
    });
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
    _textController.showHighlight = false;
    for (var i = 0; i < chunk.length; i++) {
      _textController.text += chunk[i];
      await Future.delayed(charDelay);
    }
    isAppending.value = false;
    _textController.showHighlight = true;
    _textController.notifyListeners();
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

  bool showHighlight = false;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    bool withComposing = false,
  }) {
    final baseStyle = style ?? const TextStyle();
    final spans = _parseMarkdown(text, baseStyle);
    if (!showHighlight) {
      return TextSpan(children: spans, style: baseStyle);
    }

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
        result.add(span);
      } else if (index >= highlightStart) {
        result.add(_applyGradient(span, baseStyle));
      } else {
        final before = text.substring(0, highlightStart - index);
        final after = text.substring(highlightStart - index);
        result.add(TextSpan(text: before, style: span.style));
        result.add(_applyGradient(TextSpan(text: after, style: span.style), baseStyle));
      }
      index = end;
    }

    return TextSpan(style: baseStyle, children: result);
  }

  /// Parses a very small subset of markdown (**bold**, *italic*, `code`, ## heading, tables).
  List<TextSpan> _parseMarkdown(String input, TextStyle baseStyle) {
    final spans = <TextSpan>[];
    final lines = input.split('\n');
    int i = 0;
    while (i < lines.length) {
      var line = lines[i];

      // Handle markdown tables
      if (_isTableLine(line)) {
        final tableLines = <String>[];
        while (i < lines.length && _isTableLine(lines[i])) {
          tableLines.add(lines[i]);
          i++;
        }
        spans.add(TextSpan(
            text: _formatTable(tableLines),
            style: baseStyle.copyWith(fontFamily: 'monospace')));
        if (i < lines.length) {
          spans.add(TextSpan(text: '\n', style: baseStyle));
        }
        continue;
      }

      var style = baseStyle;
      final headingMatch = RegExp(r'^(#{1,2})\s+(.*)').firstMatch(line);
      if (headingMatch != null) {
        final level = headingMatch.group(1)!.length;
        line = headingMatch.group(2)!;
        final scale = level == 1 ? 1.5 : 1.3;
        style = baseStyle.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: (baseStyle.fontSize ?? 14) * scale,
        );
      }

      final regex = RegExp(r'(\*\*.*?\*\*|\*.*?\*|`.*?`)', dotAll: true);
      int index = 0;
      for (final match in regex.allMatches(line)) {
        if (match.start > index) {
          spans.add(TextSpan(
              text: line.substring(index, match.start), style: style));
        }
        final matchText = match.group(0)!;
        if (matchText.startsWith('**')) {
          spans.add(TextSpan(
              text: matchText.substring(2, matchText.length - 2),
              style: style.copyWith(fontWeight: FontWeight.bold)));
        } else if (matchText.startsWith('*')) {
          spans.add(TextSpan(
              text: matchText.substring(1, matchText.length - 1),
              style: style.copyWith(fontStyle: FontStyle.italic)));
        } else if (matchText.startsWith('`')) {
          spans.add(TextSpan(
              text: matchText.substring(1, matchText.length - 1),
              style: style.copyWith(fontFamily: 'monospace')));
        }
        index = match.end;
      }
      if (index < line.length) {
        spans.add(TextSpan(text: line.substring(index), style: style));
      }
      if (i < lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: baseStyle));
      }
      i++;
    }
    return spans;
  }

  bool _isTableLine(String line) {
    final trimmed = line.trim();
    return trimmed.startsWith('|') && trimmed.contains('|');
  }

  String _formatTable(List<String> lines) {
    final rows = <List<String>>[];
    for (final raw in lines) {
      var line = raw.trim();
      if (line.startsWith('|')) {
        line = line.substring(1);
      }
      if (line.endsWith('|')) {
        line = line.substring(0, line.length - 1);
      }
      final cells = line.split('|').map((c) => c.trim()).toList();
      final isSeparator =
          cells.every((c) => RegExp(r'^:?-+:?$').hasMatch(c));
      if (!isSeparator) {
        rows.add(cells);
      }
    }
    if (rows.isEmpty) return '';

    final colCount = rows.map((r) => r.length).reduce(max);
    final colWidths = List<int>.filled(colCount, 0);
    for (final row in rows) {
      for (var i = 0; i < row.length; i++) {
        colWidths[i] = max(colWidths[i], row[i].length);
      }
    }

    final buffer = StringBuffer();
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      for (var c = 0; c < colCount; c++) {
        final cell = c < row.length ? row[c] : '';
        buffer.write(cell.padRight(colWidths[c]));
        if (c < colCount - 1) {
          buffer.write('   ');
        }
      }
      if (r < rows.length - 1) {
        buffer.writeln();
      }
    }
    return buffer.toString();
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
    if (!mounted) return;
    widget.onChanged?.call(widget.controller.text);
    setState(() {});
  }

  void _handleAppend() {
    if (!mounted) return;
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
      child: Theme(
        data: theme.copyWith(
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          focusColor: Colors.transparent,
        ),
        child: TextField(
          controller: widget.controller.textController,
          maxLines: null,
          style: baseStyle,
          decoration: const InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            filled: true,
            fillColor: Colors.white,
            hoverColor: Colors.white,
            focusColor: Colors.white,
          ),
        ),
      ),
    );
  }
}

