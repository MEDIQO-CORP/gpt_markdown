import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

void main() {
  testWidgets('renders controller text', (tester) async {
    final controller = GptMarkdownController(text: 'hello');
    await tester.pumpWidget(
      MaterialApp(
        home: GptMarkdownEditor(controller: controller),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('fires onChanged when text updates', (tester) async {
    final controller = GptMarkdownController();
    String? value;
    await tester.pumpWidget(
      MaterialApp(
        home: GptMarkdownEditor(
          controller: controller,
          onChanged: (v) => value = v,
        ),
      ),
    );
    controller.text = 'new text';
    await tester.pump();
    expect(value, 'new text');
  });
}
