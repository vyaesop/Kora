import 'dart:async';

import 'package:flutter/material.dart';

import 'package:kora/app_localizations.dart';
import 'package:kora/screens/login.dart';
import 'package:kora/screens/signup.dart';
import 'package:kora/utils/app_theme.dart';
import 'package:kora/utils/backend_http.dart';

class PhoneVerificationScreen extends StatefulWidget {
  final bool showBackToLogin;

  const PhoneVerificationScreen({
    super.key,
    this.showBackToLogin = true,
  });

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _sending = false;
  bool _verifying = false;
  bool _codeSent = false;
  DateTime? _resendAvailableAt;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value, AppLocalizations localizations) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return localizations.tr('required');
    return null;
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await BackendHttp.request(
        path: '/api/otp/telegram/request',
        method: 'POST',
        auth: false,
        body: {
          'phoneNumber': _phoneController.text.trim(),
        },
      );
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _resendAvailableAt = DateTime.now().add(const Duration(seconds: 30));
      });
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tr('otpSent'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() => _verifying = true);
    try {
      await BackendHttp.request(
        path: '/api/otp/telegram/verify',
        method: 'POST',
        auth: false,
        body: {
          'phoneNumber': _phoneController.text.trim(),
          'code': code,
        },
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SignupScreen(
            showBackToLogin: false,
            verifiedPhone: _phoneController.text.trim(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tr('otpInvalid'))),
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = _secondsUntilResend;
      if (remaining <= 0) {
        _resendTimer?.cancel();
        setState(() {});
      } else {
        setState(() {});
      }
    });
  }

  int get _secondsUntilResend {
    final next = _resendAvailableAt;
    if (next == null) return 0;
    final diff = next.difference(DateTime.now()).inSeconds;
    return diff < 0 ? 0 : diff;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppPalette.heroGradient,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.12 * 255).round()),
                        blurRadius: 28,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.tr('phoneVerifyTitle'),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localizations.tr('phoneVerifySubtitle'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                              height: 1.45,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? AppPalette.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark
                          ? AppPalette.darkOutline
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.tr('phoneVerifyStepTitle'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        localizations.tr('phoneVerifyStepBody'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? AppPalette.darkTextSoft
                                  : Colors.black54,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Form(
                        key: _formKey,
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          validator: (value) =>
                              _validatePhone(value, localizations),
                          decoration: InputDecoration(
                            labelText: localizations.tr('phoneLabel'),
                            hintText: localizations.tr('phone'),
                            prefixIcon: const Icon(Icons.phone_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: _sending
                              ? null
                              : (_secondsUntilResend > 0 ? null : _sendOtp),
                          child: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(
                                  _secondsUntilResend > 0
                                      ? '${localizations.tr('resendOtp')} ($_secondsUntilResend)'
                                      : localizations.tr('sendOtp'),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_codeSent)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? AppPalette.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark
                            ? AppPalette.darkOutline
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.tr('enterOtpTitle'),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          localizations.tr('enterOtpBody'),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: isDark
                                    ? AppPalette.darkTextSoft
                                    : Colors.black54,
                              ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: localizations.tr('otpLabel'),
                            hintText: localizations.tr('otpHint'),
                            prefixIcon: const Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            onPressed: _verifying ? null : _verifyOtp,
                            child: _verifying
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(localizations.tr('verifyOtp')),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                if (widget.showBackToLogin)
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: Text(localizations.tr('alreadyAccount')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
