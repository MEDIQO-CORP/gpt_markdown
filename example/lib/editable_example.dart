import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Editable Markdown Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const EditableMarkdownDemo(),
    );
  }
}

class EditableMarkdownDemo extends StatefulWidget {
  const EditableMarkdownDemo({super.key});

  @override
  State<EditableMarkdownDemo> createState() => _EditableMarkdownDemoState();
}

class _EditableMarkdownDemoState extends State<EditableMarkdownDemo> {
  String markdownText = '''# Editable Markdown Example

This is a demonstration of the editable markdown feature. Click on any plain text to edit it!

## Features

Here are some **bold** and *italic* text examples. The plain text between them is editable.

- List item 1
- List item 2
- List item 3

Try clicking on this paragraph to edit it. The editing feature only works on plain text, not on formatted markdown elements.

### Code Example

```dart
// This code block is not editable
void main() {
  print('Hello World');
}
```

This text after the code block is editable.

> This is a blockquote. The text inside might be editable depending on the implementation.

Regular paragraph text that you can click to edit.
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editable Markdown Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: GptMarkdown(
                  markdownText,
                  editable: true,
                  onTextChanged: (newText) {
                    setState(() {
                      // In a real app, you'd update the specific part that changed
                      // For this demo, we're just printing the change
                      debugPrint('Text changed to: $newText');
                    });
                  },
                ),
              ),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Click on any plain text above to edit it. Dotted underlines indicate editable text.',
                style: TextStyle(fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}