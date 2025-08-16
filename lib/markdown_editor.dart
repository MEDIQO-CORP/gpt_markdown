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

/// A markdown editor that renders the controller text directly with
/// a typewriter effect and gradient highlight on the currently typing word.
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
  late String _targetText;
  int _currentIndex = 0;
  Timer? _timer;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _targetText = widget.controller.text;
    widget.controller.addListener(_handleChange);
    _fadeController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _startAnimation();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChange);
    _timer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _handleChange() {
    _targetText = widget.controller.text;
    widget.onChanged?.call(_targetText);
    _startAnimation();
  }

  void _startAnimation() {
    _timer?.cancel();
    _fadeController.forward(from: 0);
    _currentIndex = 0;
    if (_targetText.isEmpty) {
      setState(() {});
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) return;
      setState(() {
        _currentIndex++;
      });
      if (_currentIndex >= _targetText.length) {
        timer.cancel();
      }
    });
  }

  List<InlineSpan> _buildSpans(String text) {
    final theme = Theme.of(context);
    final baseConfig =
        GptMarkdownConfig(style: theme.textTheme.bodyMedium);
    final lastSpace = text.lastIndexOf(' ');
    final before = lastSpace == -1 ? '' : text.substring(0, lastSpace + 1);
    final last = lastSpace == -1 ? text : text.substring(lastSpace + 1);
    final spans = <InlineSpan>[];
    spans.addAll(
      MarkdownComponent.generate(context, before, baseConfig, true),
    );
    if (last.isNotEmpty) {
      final paint = Paint()
        ..shader = const LinearGradient(
          colors: [
            Color.fromRGBO(119, 49, 216, 1),
            Color.fromRGBO(241, 111, 99, 1),
            Color.fromRGBO(205, 31, 134, 1),
          ],
        ).createShader(
          Rect.fromLTWH(
            0,
            0,
            (baseConfig.style?.fontSize ?? 14) * last.length,
            baseConfig.style?.fontSize ?? 14,
          ),
        );
      final gradientConfig = baseConfig.copyWith(
        style: (baseConfig.style ?? const TextStyle()).copyWith(
          foreground: paint,
        ),
      );
      spans.addAll(
        MarkdownComponent.generate(context, last, gradientConfig, true),
      );
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final text =
        _targetText.substring(0, min(_currentIndex, _targetText.length));
    return Container(
      color: Colors.white,
      child: Scrollbar(
        child: SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: FadeTransition(
            opacity: _fadeController,
            child: RichText(
              text: TextSpan(children: _buildSpans(text)),
            ),
          ),
        ),
      ),
    );
  }
}

