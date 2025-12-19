import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:sistema_educativo/models/user/user_model_v2.dart';
import 'package:sistema_educativo/providers/user_provider_v2.dart';
import 'package:sistema_educativo/utils/dialog_utils.dart';
import 'package:sistema_educativo/utils/parameters_service.dart';
import 'package:sistema_educativo/modules/user/controllers/admin_user_form_controller.dart';

import 'admin_user_form_body.dart';

part 'admin_user_form_widget_state.dart';

class AdminUserFormWidget extends StatefulWidget {
  final userModelv2? usuario;
  final bool soloLectura;
  final void Function() onSuccess;

  const AdminUserFormWidget({
    super.key,
    this.usuario,
    this.soloLectura = false,
    required this.onSuccess,
  });

  @override
  State<AdminUserFormWidget> createState() => _AdminUserFormWidgetState();
}
