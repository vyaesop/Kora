import 'package:flutter/material.dart';
import '../app_localizations.dart';
import '../screens/login.dart';
import '../screens/verification_documents_screen.dart';
import '../widgets/language_switcher.dart';
import '../utils/backend_auth_service.dart';
import '../utils/error_handler.dart';

class SignupScreen extends StatefulWidget {
  final String? initialUserType;
  final VoidCallback? onBack;
  final String? language;
  final bool showBackToLogin;

  const SignupScreen({
    super.key,
    this.initialUserType,
    this.onBack,
    this.language,
    this.showBackToLogin = true,
  });

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _authService = BackendAuthService();
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final nameController = TextEditingController();
  final usernameController = TextEditingController();
  final addressController = TextEditingController(); // Add this line
  String userType = 'Driver'; // Default user type
  String? truckType; // For drivers only
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  final truckTypes = ['Trailor', 'High bed', 'Sino Truck', '10 Tires', 'Isuzu FSR','Isuzu NPR', 'Pick up']; // Truck types for dropdown

  String? _validateEmail(String? value, AppLocalizations appLocalizations) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return appLocalizations.tr('required');
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(trimmed)) return appLocalizations.tr('invalidEmail');
    return null;
  }

  String? _validatePassword(String? value, AppLocalizations appLocalizations) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return appLocalizations.tr('required');
    if (trimmed.length < 8) return appLocalizations.tr('passwordMin');
    return null;
  }

  String? _validateRequired(String? value, AppLocalizations appLocalizations) {
    if ((value ?? '').trim().isEmpty) return appLocalizations.tr('required');
    return null;
  }

  Future<void> register() async {
    if (!mounted) return;
    final appLocalizations = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms || !_acceptedPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_acceptedTerms
              ? appLocalizations.tr('privacyRequired')
              : appLocalizations.tr('termsRequired')),
        ),
      );
      return;
    }
    if (passwordController.text.trim() !=
        confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appLocalizations.tr('passwordsNoMatch'))),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await _authService.register(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        name: nameController.text.trim(),
        userType: userType,
        phoneNumber: usernameController.text.trim(),
        username: null,
        truckType: userType == 'Driver' ? truckType : null,
        address: userType == 'Cargo' ? addressController.text.trim() : null,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const VerificationDocumentsScreen(
              isPostSignupFlow: true,
            ),
          ),
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
  void initState() {
    super.initState();
    if (widget.initialUserType != null) {
      userType = widget.initialUserType!;
    }
    // Optionally use widget.language
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    nameController.dispose();
    usernameController.dispose();
    addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: widget.onBack != null
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.black,
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [LanguageSwitcher()],
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            appLocalizations.tr('signupTitle'),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            appLocalizations.tr('signupSubtitle'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            validator: (value) =>
                                _validateEmail(value, appLocalizations),
                            decoration: InputDecoration(
                              labelText: appLocalizations.tr('emailLabel'),
                              hintText: appLocalizations.tr('email'),
                              prefixIcon: const Icon(Icons.alternate_email),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: passwordController,
                            obscureText: _obscurePassword,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: (value) =>
                                _validatePassword(value, appLocalizations),
                            decoration: InputDecoration(
                              labelText: appLocalizations.tr('passwordLabel'),
                              hintText: appLocalizations.tr('password'),
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () =>
                                    setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: confirmPasswordController,
                            obscureText: _obscurePassword,
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return appLocalizations.tr('required');
                              }
                              if (value!.trim() !=
                                  passwordController.text.trim()) {
                                return appLocalizations.tr('passwordsNoMatch');
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              labelText: appLocalizations.tr('confirmPassword'),
                              prefixIcon: const Icon(Icons.lock_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: nameController,
                            autofillHints: const [AutofillHints.name],
                            validator: (value) =>
                                _validateRequired(value, appLocalizations),
                            decoration: InputDecoration(
                              labelText: appLocalizations.tr('nameLabel'),
                              hintText: appLocalizations.tr('name'),
                              prefixIcon: const Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: usernameController,
                            keyboardType: TextInputType.phone,
                            autofillHints: const [AutofillHints.telephoneNumber],
                            validator: (value) =>
                                _validateRequired(value, appLocalizations),
                            decoration: InputDecoration(
                              labelText: appLocalizations.tr('phoneLabel'),
                              hintText: appLocalizations.tr('phone'),
                              prefixIcon: const Icon(Icons.phone_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: userType,
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                userType = value;
                              });
                            },
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            items: ['Driver', 'Cargo'].map((String type) {
                              return DropdownMenuItem<String>(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                          ),
                        if (userType == 'Driver') ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: truckType,
                            onChanged: (value) {
                              setState(() {
                                truckType = value;
                              });
                            },
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.local_shipping_outlined),
                            ),
                            hint: Text(appLocalizations.tr('truckType')),
                            items: truckTypes.map((String type) {
                              return DropdownMenuItem<String>(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                          ),
                        ] else if (userType == 'Cargo') ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: addressController,
                            decoration: InputDecoration(
                              hintText: appLocalizations.tr('businessAddress'),
                              prefixIcon: const Icon(Icons.location_on_outlined),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          value: _acceptedTerms,
                          onChanged: (v) => setState(() => _acceptedTerms = v == true),
                          title: Text(appLocalizations.tr('agreeTerms')),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                        CheckboxListTile(
                          value: _acceptedPrivacy,
                          onChanged: (v) =>
                              setState(() => _acceptedPrivacy = v == true),
                          title: Text(appLocalizations.tr('agreePrivacy')),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : register,
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(appLocalizations.tr('signup')),
                            ),
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(appLocalizations.tr('alreadyAccount')),
                              TextButton(
                              onPressed: () {
                                if (widget.showBackToLogin) {
                                  Navigator.of(context).pop();
                                  return;
                                }
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                );
                              },
                                child: Text(
                                  appLocalizations.tr('login'),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          )
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
