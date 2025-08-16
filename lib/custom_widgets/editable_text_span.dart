import 'package:flutter/material.dart';

class EditableTextSpan extends WidgetSpan {
  EditableTextSpan({
    required String text,
    required ValueChanged<String> onChanged,
    TextStyle? style,
  }) : super(
          child: _EditableTextWidget(
            text: text,
            onChanged: onChanged,
            style: style,
          ),
        );
}

class _EditableTextWidget extends StatefulWidget {
  final String text;
  final ValueChanged<String> onChanged;
  final TextStyle? style;

  const _EditableTextWidget({
    required this.text,
    required this.onChanged,
    this.style,
  });

  @override
  State<_EditableTextWidget> createState() => _EditableTextWidgetState();
}

class _EditableTextWidgetState extends State<_EditableTextWidget> {
  late TextEditingController _controller;
  bool _isEditing = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isEditing) {
        setState(() {
          _isEditing = false;
        });
        widget.onChanged(_controller.text);
      }
    });
  }

  @override
  void didUpdateWidget(_EditableTextWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text && !_isEditing) {
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return IntrinsicWidth(
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: widget.style,
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          onSubmitted: (value) {
            setState(() {
              _isEditing = false;
            });
            widget.onChanged(value);
          },
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _isEditing = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _focusNode.requestFocus();
          _controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controller.text.length,
          );
        });
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).primaryColor.withOpacity(0.3),
              width: 1,
            ),
          ),
        ),
        child: Text(
          _controller.text.isEmpty ? ' ' : _controller.text,
          style: widget.style,
        ),
      ),
    );
  }
}