import 'package:flutter/material.dart';

class ShrinkOneLine extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const ShrinkOneLine(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) => SizedBox(
        width: constraints.maxWidth,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.left,
            style: style,
          ),
        ),
      ),
    );
  }
}
