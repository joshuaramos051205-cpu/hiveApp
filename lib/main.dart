// main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'auth/auth_gate.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const HiVEApp());
}

class HiVEApp extends StatelessWidget {
  const HiVEApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HiVE',
      theme: AppTheme.darkTheme,
      home: const AuthGate(), // AuthGate auto-routes based on login state
    );
  }
}