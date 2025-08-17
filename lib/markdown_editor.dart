part of 'gpt_markdown.dart';

/// Controller used by [MarkdownEditor] to manage the current text and
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

  /// Configuration used when rendering markdown spans.
  GptMarkdownConfig? get config => _textController.config;
  set config(GptMarkdownConfig? value) => _textController.config = value;

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
// A markdown-aware [TextEditingController] that renders the current value using
// the shared markdown pipeline and applies a gradient shader to the last few
// words.
class _MarkdownEditingController extends TextEditingController {
  _MarkdownEditingController({super.text});

  /// Optional theme supplied by the surrounding editor.
  MdTheme? theme;

  /// Configuration describing how markdown should be rendered.
  GptMarkdownConfig? config;

  bool showHighlight = false;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    bool withComposing = false,
  }) {
    final baseStyle = style ?? const TextStyle();
    final effectiveTheme = theme ?? mdThemeFromMarkdownComponent(context);
    final effectiveConfig =
        (config ?? const GptMarkdownConfig()).copyWith(style: baseStyle);
    final parser = MdParser();
    final ast = parser.parse(text);
    final renderer =
        MdBlockRenderer(theme: effectiveTheme, config: effectiveConfig);
    final spans = renderer.renderBlocks(context, ast, source: text);
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

  // Previous custom markdown parsing and table construction methods have been
  // removed in favour of the shared rendering pipeline used by GptMarkdown.

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

/// Modes for rendering markdown blocks inside the editor.
enum MarkdownEditorBlockMode { inlineWidgetSpan, sliverList }

/// A markdown editor that displays rendered markdown, applies a gradient to the
/// last few words, and can animate appended text chunks.
class MarkdownEditor extends StatefulWidget {
  const MarkdownEditor({
    super.key,
    required this.controller,
    this.onChanged,
    this.theme,
    this.blockMode = MarkdownEditorBlockMode.inlineWidgetSpan,
    this.style,
    this.textAlign,
    this.textDirection = TextDirection.ltr,
    this.textScaler,
  });

  final GptMarkdownController controller;
  final ValueChanged<String>? onChanged;
  final MdTheme? theme;
  final MarkdownEditorBlockMode blockMode;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection textDirection;
  final TextScaler? textScaler;

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor>
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
    final baseStyle = widget.style ?? theme.textTheme.bodyMedium;

    // Apply theme to the underlying controller.
    final ctrl = widget.controller.textController as _MarkdownEditingController;
    ctrl.theme = widget.theme ?? mdThemeFromMarkdownComponent(context);

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
          controller: ctrl,
          maxLines: null,
          style: baseStyle,
          textAlign: widget.textAlign ?? TextAlign.start,
          textDirection: widget.textDirection,
          // Older versions of Flutter's [TextField] do not expose a `textScaler`
          // argument. Convert the optional [TextScaler] into the traditional
          // `textScaleFactor` so callers can still influence text sizing.
          textScaleFactor: widget.textScaler?.scale(1.0),
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
