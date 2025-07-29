import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ProfileField extends StatelessWidget {
  final String title;
  final String value;

  const ProfileField({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title: $value',
      readOnly: true,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$title: ",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Expanded(
              child: SelectableText(
                value,
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
