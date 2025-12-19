import 'package:flutter/material.dart';

import '../../../utils/dialog_utils.dart';
import '../export/enrollment_pdf_utils.dart';
import '../controllers/enrollment_form_controller.dart';
import '../models/submit_result.dart';

class EnrollmentSubmitHandler {
  static Future<void> handle(
    BuildContext context, {
    required SubmitResult result,
    required bool isEditing,
    required EnrollmentFormController controller,
  }) async {
    if (!result.success) {
      await DialogUtils.showError(
        context: context,
        title: 'Error al guardar',
        message: result.error ?? 'No se pudo guardar la matrícula.',
      );
      return;
    }

    final estado = result.estado ?? controller.currentEstado ?? 'prematricula';
    await DialogUtils.showSuccess(
      context: context,
      title: 'Guardado',
      message: isEditing
          ? 'La matrícula se actualizó correctamente en estado "$estado".'
          : 'La solicitud de matrícula se guardó correctamente en estado "$estado".',
    );

    if (estado == 'matriculada') {
      await EnrollmentPdfUtils.export(
        result.payload,
        estado: estado,
        anio: controller.anioMatricula ?? DateTime.now().year,
      );
      controller.setReadOnly(true);
      controller.setEstado(estado);
    } else {
      controller.setEstado(estado);
    }
  }
}
