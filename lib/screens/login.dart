import 'package:flutter/material.dart';
import 'package:kora/screens/home.dart';
// removed unused Provider import (using Riverpod instead)
import '../app_localizations.dart';
import '../widgets/language_switcher.dart';
import '../utils/backend_auth_service.dart';
import '../utils/error_handler.dart';
import 'reset_password.dart';
import 'phone_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = BackendAuthService();
  final _formKey = GlobalKey<FormState>();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  String? _validatePhone(String? value, AppLocalizations appLocalizations) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return appLocalizations.tr('required');
    return null;
  }

  String? _validatePassword(String? value, AppLocalizations appLocalizations) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return appLocalizations.tr('required');
    if (trimmed.length < 8) return appLocalizations.tr('passwordMin');
    return null;
  }

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (!mounted) return;
    if (!_formKey.currentState!.validate()) return;
    final phoneNumber = phoneController.text.trim();
    final password = passwordController.text.trim();

    setState(() => _isSubmitting = true);
    try {
      await _authService.login(
        phoneNumber: phoneNumber,
        password: password,
      );
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const Home()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = ErrorHandler.getMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [LanguageSwitcher()],
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/download.png',
                              width: 92,
                              height: 92,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 92,
                                height: 92,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withAlpha((0.12 * 255).round()),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  Icons.local_shipping_outlined,
                                  size: 44,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          appLocalizations.tr('loginTitle'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          appLocalizations.tr('loginSubtitle'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 18),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: phoneController,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.telephoneNumber
                                ],
                                validator: (value) =>
                                    _validatePhone(value, appLocalizations),
                                decoration: InputDecoration(
                                  labelText: appLocalizations.tr('phoneLabel'),
                                  hintText: appLocalizations.tr('phone'),
                                  prefixIcon: const Icon(Icons.phone_outlined),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                validator: (value) =>
                                    _validatePassword(value, appLocalizations),
                                onFieldSubmitted: (_) => login(),
                                decoration: InputDecoration(
                                  labelText: appLocalizations.tr('passwordLabel'),
                                  hintText: appLocalizations.tr('password'),
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _obscurePassword
                                        ? 'Show password'
                                        : 'Hide password',
                                    onPressed: () {
                                      setState(() => _obscurePassword = !_obscurePassword);
                                    },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const ResetPasswordScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(appLocalizations.tr('forgotPassword')),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : login,
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(appLocalizations.tr('login')),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(appLocalizations.tr('dontAccount')),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const PhoneVerificationScreen()),
                                );
                              },
                              child: Text(
                                appLocalizations.tr('signup'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        )
                      ],
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
