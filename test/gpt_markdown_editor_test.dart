import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

void main() {
  testWidgets('toggles between edit and preview', (tester) async {
    final controller = GptMarkdownController(text: 'hello');
    await tester.pumpWidget(
      MaterialApp(
        home: GptMarkdownEditor(controller: controller),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(find.byType(GptMarkdown), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });
}
