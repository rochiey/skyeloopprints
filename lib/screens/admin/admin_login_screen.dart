import 'package:flutter/material.dart';

import '../../app.dart';
import '../../theme/skyeloop_theme.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/kiosk_shell.dart';
import 'admin_dashboard_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final app = AppScope.of(context, listen: false);
    final password = _passwordController.text;
    setState(() => _error = null);
    if (app.hasAdminPassword) {
      if (!app.configService.verifyPassword(password)) {
        setState(() => _error = 'That password is not correct.');
        return;
      }
    } else {
      if (password.length < 6) {
        setState(() => _error = 'Use at least 6 characters.');
        return;
      }
      if (password != _confirmationController.text) {
        setState(() => _error = 'The passwords do not match.');
        return;
      }
      setState(() => _busy = true);
      await app.configService.setPassword(password);
    }
    await app.printerService.leaveKioskMode();
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const AdminDashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final isSetup = !app.hasAdminPassword;
    return KioskShell(
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    BrandMark(imagePath: app.config.brandingPath, size: 110),
                    const SizedBox(height: 18),
                    Text(
                      isSetup ? 'Create admin password' : 'Admin mode',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSetup
                          ? 'This password stays on this tablet. Keep it somewhere safe.'
                          : 'Enter the device password to configure this venue.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      autofocus: true,
                      onSubmitted: (_) => isSetup ? null : _continue(),
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    if (isSetup) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _confirmationController,
                        obscureText: true,
                        onSubmitted: (_) => _continue(),
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock_reset),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _continue,
                      child: _busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(isSetup ? 'Create password' : 'Unlock'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(height: 6),
                    const Text('Admin access is hidden behind a long press on the start logo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: SkyeColors.ink, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

