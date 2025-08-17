import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/index.dart';
import 'package:gpt_markdown/gpt_markdown.dart' as gm show GptMarkdown;
import 'package:gpt_markdown/custom_widgets/custom_divider.dart';

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

  testWidgets('matches GptMarkdown rendering', (tester) async {
    const text = 'Hello **world**';
    final controller = GptMarkdownController(text: text);
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            gm.GptMarkdown(text),
            GptMarkdownEditor(controller: controller),
          ],
        ),
      ),
    );
    await tester.pump();
    final rich = tester.widget<RichText>(find.descendant(
        of: find.byType(gm.GptMarkdown), matching: find.byType(RichText)));
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(rich.text.toPlainText(), editable.controller.text);
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

  testWidgets('MarkdownEditor renders tables without leading pipes or bullets',
      (tester) async {
    final controller = GptMarkdownController(
      text: 'A | B | C\n- 1 | 2 | 3\n- 4 | 5 | 6',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MarkdownEditor(controller: controller),
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

  testWidgets('scrolling stays internal', (tester) async {
    final controller = GptMarkdownController(text: List.generate(50, (i) => 'line $i').join('\n'));
    final scrollController = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 200,
          child: SingleChildScrollView(
            controller: scrollController,
            child: SizedBox(
              height: 200,
              child: GptMarkdownEditor(controller: controller),
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(GptMarkdownEditor), const Offset(0, -100));
    await tester.pump();
    expect(scrollController.offset, 0);
  });

  testWidgets('renders horizontal rule after list', (tester) async {
    final controller = GptMarkdownController(
      text: '- Item one\n- Item two\n\n--------------------\n## Next',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GptMarkdownEditor(controller: controller),
      ),
    );
    await tester.pump();

    // Horizontal rule should render as a custom divider
    expect(find.byType(CustomDivider), findsOneWidget);
    // Subsequent header text should appear separately without overlap
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('trims common leading padding', (tester) async {
    const raw = '      - Assessment:\n        - Mild scoliosis';
    final controller = GptMarkdownController(text: raw);
    await tester.pumpWidget(
      MaterialApp(
        home: GptMarkdownEditor(controller: controller),
      ),
    );
    await tester.pump();
    expect(controller.text, '- Assessment:\n  - Mild scoliosis');
  });
}
