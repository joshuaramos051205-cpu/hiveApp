// auth/register_screen.dart

import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import 'auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _loading       = false;
  bool _obscure       = true;
  String? _error;

  bool _success = false;

  Future<void> _register() async {
    if (_usernameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a username.');
      return;
    }
    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.registerWithEmail(
          _emailCtrl.text, _passwordCtrl.text, _usernameCtrl.text);
      // Sign out immediately so user lands on Login screen
      await AuthService.signOut();
      if (mounted) {
        setState(() => _success = true);
        await Future.delayed(const Duration(milliseconds: 1500));
        // Go back to Login screen
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Back ─────────────────────────────────────────────────────
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(height: 32),

              // ── Header ────────────────────────────────────────────────────
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text('🐝', style: TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 12),
                const Text('HiVE',
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primary,
                        letterSpacing: 2)),
              ]),
              const SizedBox(height: 12),
              const Text(
                'Create your account.\nBee part of the hive.',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.4),
              ),
              const SizedBox(height: 36),

              // ── Error Banner ──────────────────────────────────────────────
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade800),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.redAccent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 13)),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
              ],

              // ── Username ──────────────────────────────────────────────────
              _label('Username'),
              const SizedBox(height: 8),
              TextField(
                controller: _usernameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: 'yourhandle'),
              ),
              const SizedBox(height: 18),

              // ── Email ─────────────────────────────────────────────────────
              _label('Email'),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration:
                const InputDecoration(hintText: 'you@example.com'),
              ),
              const SizedBox(height: 18),

              // ── Password ──────────────────────────────────────────────────
              _label('Password'),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Min. 6 characters',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ── Confirm Password ──────────────────────────────────────────
              _label('Confirm Password'),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmCtrl,
                obscureText: _obscure,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: '••••••••'),
              ),
              const SizedBox(height: 32),

              // ── Register Button ───────────────────────────────────────────
              _loading
                  ? const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primary))
                  : ElevatedButton(
                onPressed: _register,
                child: const Text('Join the Hive 🐝'),
              ),

              const SizedBox(height: 28),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary),
                      children: [
                        TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Sign In',
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
        color: Colors.white70,
        fontWeight: FontWeight.w600,
        fontSize: 13),
  );
}