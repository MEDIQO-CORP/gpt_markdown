part of 'gpt_markdown.dart';

/// Controller used by [GptMarkdownEditor] to manage the current text.
class GptMarkdownController extends ChangeNotifier {
  /// Creates a controller with an optional starting [text].
  GptMarkdownController({String text = ''})
      : _textController = TextEditingController(text: text) {
    _textController.addListener(notifyListeners);
  }

  final TextEditingController _textController;

  /// Exposes the underlying [TextEditingController].
  TextEditingController get textController => _textController;

  /// Current markdown text.
  String get text => _textController.text;

  set text(String value) {
    if (_textController.text != value) {
      _textController.text = value;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}

/// A simple markdown editor that allows directly editing text with a
/// gradient style applied to the entire content.
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

class _GptMarkdownEditorState extends State<GptMarkdownEditor> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChange);
    super.dispose();
  }

  void _handleChange() {
    widget.onChanged?.call(widget.controller.text);
    // Rebuild to update gradient width when the text changes.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodyMedium;
    final text = widget.controller.text;

    // Measure the current text so the gradient spans its width.
    final painter = TextPainter(
      text: TextSpan(text: text, style: baseStyle),
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
        Rect.fromLTWH(0, 0, max(painter.size.width, 1), painter.size.height),
      );

    final style = (baseStyle ?? const TextStyle()).copyWith(foreground: paint);

    return TextField(
      controller: widget.controller.textController,
      maxLines: null,
      style: style,
      decoration: const InputDecoration(border: InputBorder.none),
    );
  }
}

