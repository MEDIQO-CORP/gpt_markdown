import 'dart:convert';

import 'package:markdown/markdown.dart' as md;

/// Simple markdown parser that enables the table syntax and exposes the
/// resulting AST nodes.
class MdParser {
  MdParser() : _document = md.Document(extensions: [md.TableSyntax()]);

  final md.Document _document;

  /// Parses [source] into a list of markdown AST nodes. If parsing fails the
  /// entire source is returned as a single [md.Text] node.
  List<md.Node> parse(String source) {
    try {
      final lines = const LineSplitter().convert(source);
      return _document.parseLines(lines);
    } catch (_) {
      return [md.Text(source)];
    }
  }
}
