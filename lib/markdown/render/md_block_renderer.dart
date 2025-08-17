import 'package:flutter/widgets.dart';
import 'package:markdown/markdown.dart' as md;

import '../../custom_widgets/markdown_config.dart';
import '../../markdown_component.dart';
import 'md_theme.dart';

/// Renders markdown AST nodes into Flutter [InlineSpan]s by delegating to the
/// existing [MarkdownComponent] pipeline used by [GptMarkdown].
class MdBlockRenderer {
  MdBlockRenderer({required this.theme});

  final MdTheme theme;

  /// Renders [ast] into spans. The [source] is used to retain the original
  /// markdown so that the existing component pipeline can handle inline syntax
  /// like bold and italics.
  List<InlineSpan> renderBlocks(BuildContext context, List<md.Node> ast,
      {required String source}) {
    // Delegate to the proven MarkdownComponent renderer which already knows how
    // to handle tables, lists, code blocks and other elements.
    final config = GptMarkdownConfig(style: theme.textStyle);
    return MarkdownComponent.generate(context, source, config, true);
  }
}
