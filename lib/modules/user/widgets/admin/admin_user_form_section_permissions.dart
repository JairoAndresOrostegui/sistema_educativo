import 'package:flutter/material.dart';

import 'package:sistema_educativo/utils/parameters_service.dart';
import 'admin_user_form_section_shared.dart';

class PermissionsSection extends StatelessWidget {
  final Map<String, List<Parameter>> groupedPermissions;
  final List<String> funcionalidades;
  final void Function(String, bool?) onFuncionalidadChanged;
  final bool soloLectura;
  const PermissionsSection({
    super.key,
    required this.groupedPermissions,
    required this.funcionalidades,
    required this.onFuncionalidadChanged,
    required this.soloLectura,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Funcionalidades',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Divider(),
        ...groupedPermissions.entries.map((entry) {
          final groupName = entry.key;
          final permissionsInGroup = entry.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ShrinkOneLine(
                  groupName.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Column(
                children: [
                  for (final perm in permissionsInGroup)
                    CheckboxListTile(
                      title: ShrinkOneLine(
                        perm.valor,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      value: funcionalidades.contains(perm.valor),
                      onChanged: soloLectura
                          ? null
                          : (bool? newValue) {
                              onFuncionalidadChanged(perm.valor, newValue);
                            },
                    ),
                ],
              ),
            ],
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}
