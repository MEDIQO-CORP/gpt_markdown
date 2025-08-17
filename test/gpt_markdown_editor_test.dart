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

    await tester.pump();
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

  testWidgets('appendMarkdown diffs and animates new text', (tester) async {
    final controller = GptMarkdownController(text: 'Hello');
    await tester.pumpWidget(
      MaterialApp(
        home: GptMarkdownEditor(controller: controller),
      ),
    );
    await controller.appendMarkdown('Hello World\n\nNew',
        charDelay: Duration.zero);
    await tester.pump();
    expect(controller.text, 'Hello World\n\nNew');
    expect(find.text('World'), findsOneWidget);
  });

  testWidgets('renders markdown tables as grid widgets', (tester) async {
    final controller = GptMarkdownController(
      text: '|A|B|\n|---|---|\n|1|2|',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GptMarkdownEditor(controller: controller),
      ),
    );
    await tester.pump();
    expect(find.byType(Table), findsOneWidget);
    expect(find.textContaining('|'), findsNothing);
  });

  testWidgets('renders tables without leading pipes or bullets', (tester) async {
    final controller = GptMarkdownController(
      text: 'A | B | C\n- 1 | 2 | 3\n- 4 | 5 | 6',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GptMarkdownEditor(controller: controller),
      ),
    );
    await tester.pump();
    expect(find.byType(Table), findsOneWidget);
    expect(find.textContaining('|'), findsNothing);
  });

  testWidgets('table reserves vertical space', (tester) async {
    final controller = GptMarkdownController(
      text: 'Above\n|A|B|\n|---|---|\n|1|2|\nBelow',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GptMarkdownEditor(controller: controller),
      ),
    );
    await tester.pump();

    final aboveBottom = tester.getBottomLeft(find.text('Above'));
    final tableTop = tester.getTopLeft(find.byType(Table));
    final belowTop = tester.getTopLeft(find.text('Below'));

    expect(aboveBottom.dy < tableTop.dy, isTrue);
    expect(tableTop.dy < belowTop.dy, isTrue);
  });
}
