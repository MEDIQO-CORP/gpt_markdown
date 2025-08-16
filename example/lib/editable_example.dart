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
  final GptMarkdownController controller = GptMarkdownController(
    text: '''# Markdown Example

AI generated **markdown** will appear below with animation.
''',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Markdown Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: GptMarkdownEditor(
        controller: controller,
        onChanged: (value) {
          // handle changes
        },
      ),
    );
  }
}
