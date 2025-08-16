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

/// A simple markdown editor with built-in edit and preview modes.
class GptMarkdownEditor extends StatefulWidget {
  const GptMarkdownEditor({super.key, required this.controller});

  final GptMarkdownController controller;

  @override
  State<GptMarkdownEditor> createState() => _GptMarkdownEditorState();
}

class _GptMarkdownEditorState extends State<GptMarkdownEditor> {
  bool _editing = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Toolbar(
          editing: _editing,
          onEdit: () => setState(() => _editing = true),
          onPreview: () => setState(() => _editing = false),
        ),
        Expanded(
          child: _editing ? _buildEditor() : _buildPreview(),
        ),
      ],
    );
  }

  Widget _buildEditor() {
    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: TextField(
          controller: widget.controller.textController,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(border: InputBorder.none),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: GptMarkdown(
          widget.controller.text,
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.editing,
    required this.onEdit,
    required this.onPreview,
  });

  final bool editing;
  final VoidCallback onEdit;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    TextStyle? active(TextStyle? style, bool active) =>
        active ? style?.copyWith(fontWeight: FontWeight.bold) : style;
    return Material(
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          TextButton(
            onPressed: onEdit,
            child: Text(
              'Edit',
              style: active(theme.textTheme.labelLarge, editing),
            ),
          ),
          TextButton(
            onPressed: onPreview,
            child: Text(
              'Preview',
              style: active(theme.textTheme.labelLarge, !editing),
            ),
          ),
        ],
      ),
    );
  }
}
