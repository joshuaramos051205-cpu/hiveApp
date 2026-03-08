// auth/auth_gate.dart
// Listens to Firebase auth state — routes to Login or MainNav automatically.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../navigation/main_nav.dart';
import 'auth_service.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.userStream,
      builder: (context, snapshot) {
        // While Firebase checks the persisted session, show a splash
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _HiveSplash();
        }
        // User is logged in → go to app
        if (snapshot.hasData && snapshot.data != null) {
          return const MainNav();
        }
        // Not logged in → show login
        return const LoginScreen();
      },
    );
  }
}

class _HiveSplash extends StatelessWidget {
  const _HiveSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🐝', style: TextStyle(fontSize: 56)),
            SizedBox(height: 12),
            Text(
              'HiVE',
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFFD600),
                letterSpacing: 4,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Color(0xFFFFD600)),
          ],
        ),
      ),
    );
  }
}