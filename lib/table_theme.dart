part of 'gpt_markdown.dart';

class MarkdownTableStyle {
  final EdgeInsets cellPadding;
  final Color borderColor;
  final Color headerColor;

  const MarkdownTableStyle({
    this.cellPadding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    required this.borderColor,
    required this.headerColor,
  });

  factory MarkdownTableStyle.of(BuildContext context) {
    final theme = Theme.of(context);
    return MarkdownTableStyle(
      borderColor: theme.colorScheme.onSurface,
      headerColor: theme.colorScheme.surfaceContainerHighest,
    );
  }
}
