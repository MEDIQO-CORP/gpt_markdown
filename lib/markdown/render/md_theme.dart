import 'package:flutter/material.dart';

/// Theme information used by the markdown rendering pipeline.
class MdTheme {
  const MdTheme({required this.textStyle});

  /// Base text style for markdown content.
  final TextStyle textStyle;
}

/// Creates an [MdTheme] from the current [BuildContext].
MdTheme mdThemeFromMarkdownComponent(BuildContext context) {
  final style = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
  return MdTheme(textStyle: style);
}
