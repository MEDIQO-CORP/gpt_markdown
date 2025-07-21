# How to Use gpt_markdown in Your Project

You have several options to use this modified version of gpt_markdown with the new editable text feature:

## Option 1: Local Path Dependency

If you have the package locally on your machine, add this to your `pubspec.yaml`:

```yaml
dependencies:
  gpt_markdown:
    path: /Users/behradizadi/samples/gpt_markdown
```

## Option 2: Git Dependency

If you push this to a Git repository (e.g., GitHub), you can reference it directly:

```yaml
dependencies:
  gpt_markdown:
    git:
      url: https://github.com/YOUR_USERNAME/gpt_markdown.git
      ref: main  # or specific branch/tag
```

## Option 3: Fork and Publish

1. Fork the original repository
2. Apply your changes
3. Publish to pub.dev under a different name:
   - Change the package name in `pubspec.yaml` (e.g., `gpt_markdown_editable`)
   - Run `flutter pub publish`

## Option 4: Create a Pull Request

Consider contributing your editable text feature back to the original repository:
1. Fork the original repo: https://github.com/Infinitix-LLC/gpt_markdown
2. Apply your changes
3. Create a pull request

## Using the Editable Feature

Once you have the package in your project:

```dart
import 'package:gpt_markdown/gpt_markdown.dart';

// In your widget:
GptMarkdown(
  markdownText,
  editable: true,
  onTextChanged: (newText) {
    // Handle text changes
    setState(() {
      // Update your text or handle the change
    });
  },
)
```

## Features Added

- ✏️ **Editable Text**: Click on plain text portions to edit them inline
- 🎯 **`editable` parameter**: Enable/disable editing mode
- 📝 **`onTextChanged` callback**: Handle text modifications
- 🎨 **Visual Indicator**: Dotted underline shows editable text

## Running the Example

To test the editable feature:

```bash
cd example
flutter run -d macos  # or your preferred device
```

Then run the `editable_example.dart` file to see the feature in action.