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

  /// Computes the diff between the current text and [nextMarkdown] and animates
  /// the inserted segments with a typewriter effect.
  Future<void> appendMarkdown(String nextMarkdown,
      {Duration charDelay = Duration.zero}) async {
    final current = _textController.text;
    if (nextMarkdown == current) return;

    // Find common prefix.
    var prefixLength = 0;
    while (
        prefixLength < current.length &&
        prefixLength < nextMarkdown.length &&
        current[prefixLength] == nextMarkdown[prefixLength]) {
      prefixLength++;
    }

    // Find common suffix after removing prefix.
    final currentSuffix = current.substring(prefixLength);
    final nextSuffix = nextMarkdown.substring(prefixLength);
    var suffixLength = 0;
    while (
        suffixLength < currentSuffix.length &&
        suffixLength < nextSuffix.length &&
        currentSuffix[currentSuffix.length - 1 - suffixLength] ==
            nextSuffix[nextSuffix.length - 1 - suffixLength]) {
      suffixLength++;
    }

    final inserted =
        nextMarkdown.substring(prefixLength, nextMarkdown.length - suffixLength);

    // Replace existing content with the unchanged prefix before animating.
    _textController.text = nextMarkdown.substring(0, prefixLength);

    if (inserted.isEmpty) {
      _textController.text +=
          nextMarkdown.substring(nextMarkdown.length - suffixLength);
      _textController.notifyListeners();
      return;
    }

    final chunks = _splitIntoChunks(inserted);
    for (final chunk in chunks) {
      if (chunk.isEmpty) continue;
      isAppending.value = true;
      _textController.showHighlight = false;
      for (var i = 0; i < chunk.length; i++) {
        _textController.text += chunk[i];
        if (charDelay > Duration.zero) {
          await Future.delayed(charDelay);
        }
      }
      isAppending.value = false;
      _textController.showHighlight = true;
      _textController.notifyListeners();
    }

    // Append the remaining suffix and notify listeners.
    _textController.text +=
        nextMarkdown.substring(nextMarkdown.length - suffixLength);
    _textController.notifyListeners();
  }

  List<String> _splitIntoChunks(String text) {
    final parts = text.split('\n\n');
    final result = <String>[];
    for (var i = 0; i < parts.length; i++) {
      final segment = parts[i];
      if (segment.isEmpty) continue;
      if (i != parts.length - 1) {
        result.add('$segment\n\n');
      } else {
        result.add(segment);
      }
    }
    return result;
  }

  @override
  void dispose() {
    _textController.dispose();
    isAppending.dispose();
    super.dispose();
  }
}

/// Base class for parsed markdown blocks.
abstract class _MarkdownBlock {}

/// Inline text such as paragraphs or headings.
class _ParagraphBlock extends _MarkdownBlock {
  _ParagraphBlock(this.text);
  final String text;
}

/// Block widget such as a table.
class _TableBlock extends _MarkdownBlock {
  _TableBlock(this.lines);
  final List<String> lines;
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

    final plainText =
        spans.map((s) => s is TextSpan ? (s.text ?? '') : '').join();
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
      if (span is! TextSpan) {
        result.add(span);
        continue;
      }
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
        result.add(
            _applyGradient(TextSpan(text: after, style: span.style), baseStyle));
      }
      index = end;
    }

    return TextSpan(style: baseStyle, children: result);
  }

  /// Breaks the markdown into block level nodes before rendering. This prevents
  /// large widgets like tables from overlapping adjacent text by ensuring they
  /// occupy their own line in the flow.
  List<InlineSpan> _parseMarkdown(String input, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    final blocks = _composeBlocks(input);
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (block is _TableBlock) {
        spans.add(_buildTable(block.lines, baseStyle));
      } else if (block is _ParagraphBlock) {
        spans.addAll(_parseInline(block.text, baseStyle));
      }
      if (i != blocks.length - 1) {
        spans.add(TextSpan(text: '\n', style: baseStyle));
      }
    }
    return spans;
  }

  /// Parses inline markdown for a single paragraph or heading.
  List<InlineSpan> _parseInline(String text, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
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
          spans.add(
              TextSpan(text: line.substring(index, match.start), style: style));
        }
        final matchText = match.group(0)!;
        if (matchText.startsWith('**') &&
            matchText.endsWith('**') &&
            matchText.length >= 4) {
          spans.add(TextSpan(
              text: matchText.substring(2, matchText.length - 2),
              style: style.copyWith(fontWeight: FontWeight.bold)));
        } else if (matchText.startsWith('*') &&
            matchText.endsWith('*') &&
            matchText.length >= 2) {
          spans.add(TextSpan(
              text: matchText.substring(1, matchText.length - 1),
              style: style.copyWith(fontStyle: FontStyle.italic)));
        } else if (matchText.startsWith('`') &&
            matchText.endsWith('`') &&
            matchText.length >= 2) {
          spans.add(TextSpan(
              text: matchText.substring(1, matchText.length - 1),
              style: style.copyWith(fontFamily: 'monospace')));
        } else {
          spans.add(TextSpan(text: matchText, style: style));
        }
        index = match.end;
      }
      if (index < line.length) {
        spans.add(TextSpan(text: line.substring(index), style: style));
      }
      if (i != lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: baseStyle));
      }
    }
    return spans;
  }

  /// Splits the raw markdown into block nodes. Currently supports paragraphs
  /// and tables but is easily extensible for other block level widgets.
  List<_MarkdownBlock> _composeBlocks(String input) {
    final lines = input.split('\n');
    final blocks = <_MarkdownBlock>[];
    int i = 0;
    while (i < lines.length) {
      if (_isTableLine(lines[i])) {
        final tableLines = <String>[];
        while (i < lines.length && _isTableLine(lines[i])) {
          tableLines.add(lines[i]);
          i++;
        }
        blocks.add(_TableBlock(tableLines));
      } else {
        final buffer = StringBuffer();
        while (i < lines.length && !_isTableLine(lines[i])) {
          buffer.writeln(lines[i]);
          i++;
        }
        blocks.add(_ParagraphBlock(buffer.toString().trimRight()));
      }
    }
    return blocks;
  }

  bool _isTableLine(String line) {
    var trimmed = line.trimLeft();
    if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
      trimmed = trimmed.substring(2).trimLeft();
    } else {
      final match = RegExp(r'^\d+[.)]\s+').firstMatch(trimmed);
      if (match != null) {
        trimmed = trimmed.substring(match.end).trimLeft();
      }
    }
    return trimmed.contains('|');
  }

  InlineSpan _buildTable(List<String> lines, TextStyle baseStyle) {
    final rows = <List<String>>[];
    for (final raw in lines) {
      var line = raw.trim();
      if (line.startsWith('- ') || line.startsWith('* ')) {
        line = line.substring(2).trimLeft();
      } else {
        final match = RegExp(r'^\d+[.)]\s+').firstMatch(line);
        if (match != null) {
          line = line.substring(match.end).trimLeft();
        }
      }
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

    final tableRows = <TableRow>[];
    for (final row in rows) {
      tableRows.add(
        TableRow(
          children: [
            for (final cell in row)
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text(cell, style: baseStyle),
              ),
          ],
        ),
      );
    }

    // Use top alignment so the table occupies the full vertical space of its
    // line, preventing it from overlapping adjacent text.
    return WidgetSpan(
      alignment: PlaceholderAlignment.top,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(color: Colors.grey.shade400),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: tableRows,
        ),
      ),
    );
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
        AnimationController(vsync: this, duration: const Duration(milliseconds: 100))
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

