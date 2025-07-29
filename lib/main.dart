import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:sistema_educativo/config/firebase_options.dart'; 

import 'package:sistema_educativo/app.dart';
import 'package:sistema_educativo/modules/auth/providers/user_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    ChangeNotifierProvider(
      create: (context) => UsuarioProvider()..cargarUsuario(FirebaseAuth.instance.currentUser?.uid),
      child: const AppRouter(),
    ),
  );
}
