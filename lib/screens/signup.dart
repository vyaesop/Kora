import 'package:flutter/material.dart';
import 'package:Kora/screens/home.dart'; // Add this import if not present
// removed unused Provider import (project uses Riverpod)
import '../app_localizations.dart';
import '../widgets/Language_Switcher.dart';
import '../utils/backend_auth_service.dart';

class SignupScreen extends StatefulWidget {
  final String? initialUserType;
  final VoidCallback? onBack;
  final String? language;

  const SignupScreen({super.key, this.initialUserType, this.onBack, this.language});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _authService = BackendAuthService();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final usernameController = TextEditingController();
  final addressController = TextEditingController(); // Add this line
  String userType = 'Driver'; // Default user type
  String? truckType; // For drivers only
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  final truckTypes = ['Trailor', 'High bed', 'Sino Truck', '10 Tires', 'Isuzu FSR','Isuzu NPR', 'Pick up']; // Truck types for dropdown

  Future<void> register() async {
    if (!mounted) return;
    if (!_acceptedTerms || !_acceptedPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept Terms and Privacy Policy to continue.')),
      );
      return;
    }
    try {
      await _authService.register(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        name: nameController.text.trim(),
        userType: userType,
        username: usernameController.text.trim(),
        truckType: userType == 'Driver' ? truckType : null,
        address: userType == 'Cargo' ? addressController.text.trim() : null,
      );

      if (mounted) {
        // User is already logged in after sign up, so go to Home
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => const Home()));
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = "Registration failed: $e";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
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
          child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                LanguageSwitcher(),
              ],
            ),
            
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: TextFormField(
                controller: emailController,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.all(8),
                  hintText: appLocalizations.tr('email'),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.grey,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.all(8),
                  hintText: appLocalizations.tr('password'),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.grey,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: TextFormField(
                controller: nameController,
                decoration:  InputDecoration(
                  contentPadding: EdgeInsets.all(8),
                  hintText: appLocalizations.tr('name'),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.grey,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: TextFormField(
                controller: usernameController,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.all(8),
                  hintText: appLocalizations.tr('phone'),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.grey,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: DropdownButtonFormField<String>(
                value: userType,
                onChanged: (value) {
                  setState(() {
                    userType = value!;
                  });
                },
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(8),
                  border: OutlineInputBorder(),
                ),
                items: ['Driver', 'Cargo'].map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
              ),
            ),
            if (userType == 'Driver') ...[
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: DropdownButtonFormField<String>(
                  value: truckType,
                  onChanged: (value) {
                    setState(() {
                      truckType = value;
                    });
                  },
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(8),
                    border: OutlineInputBorder(),
                  ),
                  hint: Text(appLocalizations.tr('truckType')),
                  items: truckTypes.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                ),
              ),
            ] else if (userType == 'Cargo') ...[
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: TextFormField(
                  controller: addressController,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.all(8),
                    hintText: 'Business Address',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _acceptedTerms,
              onChanged: (v) => setState(() => _acceptedTerms = v == true),
              title: const Text('I agree to the Terms of Service'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              value: _acceptedPrivacy,
              onChanged: (v) => setState(() => _acceptedPrivacy = v == true),
              title: const Text('I agree to the Privacy Policy'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton(
                  onPressed: register,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                  child: Text(appLocalizations.tr('signup')),
                ),
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(appLocalizations.tr('alreadyAccount')),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    "Login",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ],
            )
          ],
        ),
      )),
    );
  }
}
