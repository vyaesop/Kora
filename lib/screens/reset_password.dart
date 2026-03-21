import 'package:flutter/material.dart';

import '../app_localizations.dart';
import '../utils/backend_auth_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? initialEmail;
  final String? initialToken;

  const ResetPasswordScreen({
    super.key,
    this.initialEmail,
    this.initialToken,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _authService = BackendAuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail ?? '';
    _tokenController.text = widget.initialToken ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value, AppLocalizations localizations) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return localizations.tr('required');
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(trimmed)) return localizations.tr('invalidEmail');
    return null;
  }

  String? _validatePassword(String? value, AppLocalizations localizations) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return localizations.tr('required');
    if (trimmed.length < 8) return localizations.tr('passwordMin');
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final localizations = AppLocalizations.of(context);
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.tr('passwordsNoMatch'))),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _authService.resetPassword(
        email: _emailController.text.trim(),
        token: _tokenController.text.trim(),
        newPassword: password,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.tr('passwordResetSuccess'))),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${localizations.tr('passwordResetFailed')}${e.toString().replaceFirst('Exception: ', '')}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.tr('resetPasswordTitle')),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            localizations.tr('resetPasswordSubtitle'),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) =>
                                _validateEmail(value, localizations),
                            decoration: InputDecoration(
                              labelText: localizations.tr('emailLabel'),
                              hintText: localizations.tr('email'),
                              prefixIcon: const Icon(Icons.alternate_email),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _tokenController,
                            validator: (value) => (value ?? '').trim().isEmpty
                                ? localizations.tr('required')
                                : null,
                            decoration: InputDecoration(
                              labelText: localizations.tr('resetTokenLabel'),
                              hintText: localizations.tr('resetTokenHint'),
                              prefixIcon: const Icon(Icons.vpn_key_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscure,
                            validator: (value) =>
                                _validatePassword(value, localizations),
                            decoration: InputDecoration(
                              labelText: localizations.tr('newPasswordLabel'),
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _obscure
                                    ? localizations.tr('showPassword')
                                    : localizations.tr('hidePassword'),
                                icon: Icon(
                                    _obscure ? Icons.visibility_off : Icons.visibility),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmController,
                            obscureText: _obscure,
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return localizations.tr('required');
                              }
                              if (value!.trim() !=
                                  _passwordController.text.trim()) {
                                return localizations.tr('passwordsNoMatch');
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              labelText: localizations.tr('confirmPassword'),
                              prefixIcon: const Icon(Icons.lock_outline),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: _submitting ? null : _submit,
                              child: _submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child:
                                          CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(localizations.tr('resetPasswordCta')),
                            ),
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
      ),
    );
  }
}
