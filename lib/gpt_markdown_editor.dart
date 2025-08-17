import 'package:flutter/material.dart';

// Bring in markdown configuration and theme helpers that are not re-exported by
// `gpt_markdown.dart`. Without these imports, the builder typedefs such as
// [LatexBuilder] or [CodeBlockBuilder] and the `mdThemeFromMarkdownComponent`
// function are unresolved when compiling this file.
import 'custom_widgets/markdown_config.dart';
import 'markdown/render/md_theme.dart';

import 'gpt_markdown.dart';

/// Editable variant of [GptMarkdown] that renders markdown spans while allowing
/// in-place text editing through a [GptMarkdownController].
class GptMarkdownEditor extends StatelessWidget {
  const GptMarkdownEditor({
    super.key,
    required this.controller,
    this.onChanged,
    this.style,
    this.followLinkColor = false,
    this.textDirection = TextDirection.ltr,
    this.latexWorkaround,
    this.textAlign,
    this.imageBuilder,
    this.textScaler,
    this.onLinkTap,
    this.latexBuilder,
    this.codeBuilder,
    this.sourceTagBuilder,
    this.highlightBuilder,
    this.linkBuilder,
    this.maxLines,
    this.overflow,
    this.orderedListBuilder,
    this.unOrderedListBuilder,
    this.tableBuilder,
    this.components,
    this.inlineComponents,
    this.useDollarSignsForLatex = false,
  });

  /// Controls the current markdown text being edited.
  final GptMarkdownController controller;

  /// Fired whenever the text changes.
  final ValueChanged<String>? onChanged;

  /// The direction of the text.
  final TextDirection textDirection;

  /// The style of the text.
  final TextStyle? style;

  /// The alignment of the text.
  final TextAlign? textAlign;

  /// The text scaler.
  final TextScaler? textScaler;

  /// The callback function to handle link clicks.
  final void Function(String url, String title)? onLinkTap;

  /// The LaTeX workaround.
  final String Function(String tex)? latexWorkaround;
  final int? maxLines;

  /// The overflow.
  final TextOverflow? overflow;

  /// The LaTeX builder.
  final LatexBuilder? latexBuilder;

  /// Whether to follow the link color.
  final bool followLinkColor;

  /// The code builder.
  final CodeBlockBuilder? codeBuilder;

  /// The source tag builder.
  final SourceTagBuilder? sourceTagBuilder;

  /// The highlight builder.
  final HighlightBuilder? highlightBuilder;

  /// The link builder.
  final LinkBuilder? linkBuilder;

  /// The image builder.
  final ImageBuilder? imageBuilder;

  /// The ordered list builder.
  final OrderedListBuilder? orderedListBuilder;

  /// The unordered list builder.
  final UnOrderedListBuilder? unOrderedListBuilder;

  /// Whether to use dollar signs for LaTeX.
  final bool useDollarSignsForLatex;

  /// The table builder.
  final TableBuilder? tableBuilder;

  /// The list of components.
  final List<MarkdownComponent>? components;

  /// The list of inline components.
  final List<MarkdownComponent>? inlineComponents;

  @override
  Widget build(BuildContext context) {
    String tex = controller.text.trim();
    if (useDollarSignsForLatex) {
      tex = tex.replaceAllMapped(
        RegExp(r"(?<!\\)\$\$(.*?)(?<!\\)\$\$", dotAll: true),
        (match) => "\\[${match[1] ?? ""}\\]",
      );
      if (!tex.contains(r"\(")) {
        tex = tex.replaceAllMapped(
          RegExp(r"(?<!\\)\$(.*?)(?<!\\)\$"),
          (match) => "\\(${match[1] ?? ""}\\)",
        );
        tex = tex.splitMapJoin(
          RegExp(r"\[.*?\]|\(.*?\)"),
          onNonMatch: (p0) {
            return p0.replaceAll("\\\$", "\$");
          },
        );
      }
    }

    // Apply the configuration to the underlying controller so it renders using
    // the same pipeline as [GptMarkdown].
    controller.config = GptMarkdownConfig(
      textDirection: textDirection,
      style: style,
      onLinkTap: onLinkTap,
      textAlign: textAlign,
      textScaler: textScaler,
      followLinkColor: followLinkColor,
      latexWorkaround: latexWorkaround,
      latexBuilder: latexBuilder,
      codeBuilder: codeBuilder,
      maxLines: maxLines,
      overflow: overflow,
      sourceTagBuilder: sourceTagBuilder,
      highlightBuilder: highlightBuilder,
      linkBuilder: linkBuilder,
      imageBuilder: imageBuilder,
      orderedListBuilder: orderedListBuilder,
      unOrderedListBuilder: unOrderedListBuilder,
      components: components,
      inlineComponents: inlineComponents,
      tableBuilder: tableBuilder,
      editable: true,
      onTextChanged: onChanged,
    );

    return ClipRRect(
      child: MarkdownEditor(
        controller: controller,
        onChanged: onChanged,
        theme: mdThemeFromMarkdownComponent(context),
        style: style,
        textAlign: textAlign,
        textDirection: textDirection,
        textScaler: textScaler,
      ),
    );
  }
}

