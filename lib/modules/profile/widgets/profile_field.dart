import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class ProfileField extends StatelessWidget {
  final String title;
  final String value;

  final bool forceStackOnMobile;

  final double stackBreakpoint;

  final EdgeInsetsGeometry padding;
  final TextStyle? titleStyle;
  final TextStyle? valueStyle;

  const ProfileField({
    super.key,
    required this.title,
    required this.value,
    this.forceStackOnMobile = true,
    this.stackBreakpoint = 600,
    this.padding = const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    this.titleStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    final defaultTitle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: Colors.black87,
    );
    final defaultValue = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w500,
      color: Colors.black87,
    );

    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shouldStack =
              !kIsWeb &&
              (forceStackOnMobile || constraints.maxWidth < stackBreakpoint);

          if (shouldStack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$title:', style: titleStyle ?? defaultTitle),
                const SizedBox(height: 4),
                SelectableText(
                  value.isEmpty ? '-' : value,
                  style: valueStyle ?? defaultValue,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 120),
                child: Text('$title:', style: titleStyle ?? defaultTitle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SelectableText(
                  value.isEmpty ? '-' : value,
                  style: valueStyle ?? defaultValue,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
