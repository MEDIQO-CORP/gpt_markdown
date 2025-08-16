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
    final spans = _parseMarkdown(context, text, baseStyle);
    final flatSpans = _flattenSpans(spans);
    if (!showHighlight) {
      return TextSpan(children: flatSpans, style: baseStyle);
    }

    final plainText =
        flatSpans.whereType<TextSpan>().map((s) => s.text ?? '').join();
    final wordMatches = RegExp(r'\b\w+\b').allMatches(plainText).toList();
    if (wordMatches.isEmpty) {
      return TextSpan(children: flatSpans, style: baseStyle);
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
    for (final span in flatSpans) {
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

  List<InlineSpan> _parseMarkdown(
      BuildContext context, String input, TextStyle baseStyle) {
    final document = md.Document(
      extensionSet: md.ExtensionSet.gitHubWeb,
      encodeHtml: false,
    );
    final nodes = document.parseLines(input.split('\n'));
    final spans = <InlineSpan>[];
    for (final node in nodes) {
      spans.add(_nodeToSpan(context, node, baseStyle));
      if (node != nodes.last) {
        spans.add(TextSpan(text: '\n', style: baseStyle));
      }
    }
    return spans;
  }

  InlineSpan _nodeToSpan(
      BuildContext context, md.Node node, TextStyle style) {
    if (node is md.Text) {
      return TextSpan(text: node.text, style: style);
    }
    if (node is md.Element) {
      switch (node.tag) {
        case 'p':
          return TextSpan(
            style: style,
            children:
                node.children?.map((c) => _nodeToSpan(context, c, style)).toList(),
          );
        case 'h1':
        case 'h2':
          final level = int.parse(node.tag.substring(1));
          final scale = level == 1 ? 1.5 : 1.3;
          final headingStyle = style.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: (style.fontSize ?? 14) * scale,
          );
          return TextSpan(
            style: headingStyle,
            children: node.children
                ?.map((c) => _nodeToSpan(context, c, headingStyle))
                .toList(),
          );
        case 'strong':
          final boldStyle = style.copyWith(fontWeight: FontWeight.bold);
          return TextSpan(
            style: boldStyle,
            children: node.children
                ?.map((c) => _nodeToSpan(context, c, boldStyle))
                .toList(),
          );
        case 'em':
          final italicStyle = style.copyWith(fontStyle: FontStyle.italic);
          return TextSpan(
            style: italicStyle,
            children: node.children
                ?.map((c) => _nodeToSpan(context, c, italicStyle))
                .toList(),
          );
        case 'code':
          final text = node.children
                  ?.map((n) => n is md.Text ? n.text : '')
                  .join() ??
              '';
          return TextSpan(
            text: text,
            style: style.copyWith(fontFamily: 'monospace'),
          );
        case 'table':
          return WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _buildTableElement(context, node, style),
          );
        default:
          return TextSpan(
            style: style,
            children: node.children
                ?.map((c) => _nodeToSpan(context, c, style))
                .toList(),
          );
      }
    }
    return TextSpan(text: '', style: style);
  }

  Widget _buildTableElement(
      BuildContext context, md.Element table, TextStyle baseStyle) {
    final style = MarkdownTableStyle.of(context);
    final rows = <TableRow>[];
    final alignments = <TextAlign>[];

    md.Element? thead;
    md.Element? tbody;
    for (final child in table.children!.whereType<md.Element>()) {
      if (child.tag == 'thead') thead = child;
      if (child.tag == 'tbody') tbody = child;
    }

    if (thead != null && thead.children!.isNotEmpty) {
      final headerRow = thead.children!.first as md.Element;
      final headerCells = headerRow.children!.whereType<md.Element>().toList();
      final headerWidgets = <Widget>[];
      for (final cell in headerCells) {
        final align = _cellAlignment(cell);
        alignments.add(align);
        headerWidgets.add(
          _buildTableCell(
            context,
            cell,
            baseStyle.copyWith(fontWeight: FontWeight.bold),
            style,
            align,
          ),
        );
      }
      rows.add(
        TableRow(
          decoration: BoxDecoration(color: style.headerColor),
          children: headerWidgets,
        ),
      );
    }

    final bodyRows = tbody != null
        ? tbody.children!.whereType<md.Element>().toList()
        : table.children!
            .whereType<md.Element>()
            .where((e) => e.tag == 'tr')
            .toList();

    for (final row in bodyRows) {
      final cells = row.children!.whereType<md.Element>().toList();
      final children = <Widget>[];
      for (var i = 0; i < cells.length; i++) {
        final cell = cells[i];
        TextAlign align =
            (alignments.length > i) ? alignments[i] : _cellAlignment(cell);
        if (alignments.length <= i) alignments.add(align);
        children.add(
          _buildTableCell(context, cell, baseStyle, style, align),
        );
      }
      rows.add(TableRow(children: children));
    }

    final controller = ScrollController();
    return Scrollbar(
      controller: controller,
      child: SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: TableBorder.all(color: style.borderColor, width: 1),
          children: rows,
        ),
      ),
    );
  }

  TextAlign _cellAlignment(md.Element cell) {
    final style = cell.attributes['style'];
    if (style != null) {
      if (style.contains('center')) return TextAlign.center;
      if (style.contains('right')) return TextAlign.right;
    }
    return TextAlign.left;
  }

  Widget _buildTableCell(BuildContext context, md.Element cell,
      TextStyle baseStyle, MarkdownTableStyle tableStyle, TextAlign align) {
    final spans = cell.children
            ?.map((c) => _nodeToSpan(context, c, baseStyle))
            .toList() ??
        [];
    Widget content = RichText(
      text: TextSpan(style: baseStyle, children: spans),
    );
    content = Padding(padding: tableStyle.cellPadding, child: content);
    switch (align) {
      case TextAlign.center:
        content = Center(child: content);
        break;
      case TextAlign.right:
        content = Align(alignment: Alignment.centerRight, child: content);
        break;
      case TextAlign.left:
      default:
        content = Align(alignment: Alignment.centerLeft, child: content);
        break;
    }
    return content;
  }

  List<InlineSpan> _flattenSpans(List<InlineSpan> spans) {
    final result = <InlineSpan>[];
    for (final span in spans) {
      if (span is TextSpan && span.children != null && span.children!.isNotEmpty) {
        if (span.text != null && span.text!.isNotEmpty) {
          result.add(TextSpan(text: span.text, style: span.style));
        }
        result.addAll(_flattenSpans(span.children!));
      } else {
        result.add(span);
      }
    }
    return result;
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

