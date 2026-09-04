import 'package:flutter/material.dart';

class ShrinkOneLine extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const ShrinkOneLine(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.left,
    style: style,
  );
}
