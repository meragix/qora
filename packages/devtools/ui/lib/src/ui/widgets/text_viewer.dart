import 'dart:math';

import 'package:flutter/material.dart';

/// A wrapper for a Text widget, which allows for concatenating text if it
/// becomes too long.
class TextViewer extends StatelessWidget {
  const TextViewer({
    super.key,
    required this.text,
    this.maxLength = 65536, //2^16
    this.style,
  });

  final String text;
  final int maxLength;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final String displayText;
    // Limit the length of the displayed text to maxLength
    if (text.length > maxLength) {
      displayText = '${text.substring(0, min(maxLength, text.length))}...';
    } else {
      displayText = text;
    }
    return SelectionArea(child: Text(displayText, style: style));
  }
}
