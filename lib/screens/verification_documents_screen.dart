import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:kora/screens/home.dart';
import 'package:kora/utils/app_theme.dart';
import 'package:kora/utils/backend_auth_service.dart';
import 'package:kora/utils/backend_http.dart';
import 'package:kora/utils/error_handler.dart';
import 'package:kora/utils/verification_access.dart';
import 'package:kora/widgets/document_image.dart';

class VerificationDocumentsScreen extends StatefulWidget {
  final bool isPostSignupFlow;

  const VerificationDocumentsScreen({super.key, this.isPostSignupFlow = false});

  @override
  State<VerificationDocumentsScreen> createState() =>
      _VerificationDocumentsScreenState();
}

class _VerificationDocumentsScreenState
    extends State<VerificationDocumentsScreen> {
  final BackendAuthService _authService = BackendAuthService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _tinNumberController = TextEditingController();
  final TextEditingController _libreController = TextEditingController();
  final TextEditingController _vehiclePlateController = TextEditingController();

  String? _userId;
  String _userType = 'Cargo';
  String _verificationStatus = 'not_submitted';
  String? _verificationNote;
  String? _nationalIdPhoto;
  String? _driverLicensePhoto;
  String? _tradeLicensePhoto;
  String? _tradeRegistrationCertificatePhoto;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _tinNumberController.dispose();
    _libreController.dispose();
    _vehiclePlateController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    try {
      await _authService.restoreSession();
      final user = await _authService.getStoredUserMap();
      if (!mounted) return;

      _tinNumberController.text = (user?['tinNumber'] ?? '').toString();
      _libreController.text = (user?['libre'] ?? '').toString();
      _vehiclePlateController.text = (user?['licensePlate'] ?? '').toString();

      setState(() {
        _userId = user?['id']?.toString();
        _userType = (user?['userType'] ?? 'Cargo').toString();
        _verificationStatus = VerificationAccess.normalizeStatus(
          user?['verificationStatus']?.toString(),
        );
        _verificationNote = user?['verificationNote']?.toString();
        _nationalIdPhoto = user?['idPhoto']?.toString();
        _driverLicensePhoto = user?['licenseNumberPhoto']?.toString();
        _tradeLicensePhoto = user?['tradeLicensePhoto']?.toString();
        _tradeRegistrationCertificatePhoto =
            user?['tradeRegistrationCertificatePhoto']?.toString();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto(String key) async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1800,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final extension = file.path.toLowerCase();
    final mimeType = extension.endsWith('.png') ? 'image/png' : 'image/jpeg';
    final dataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';

    if (!mounted) return;
    setState(() {
      switch (key) {
        case 'nationalIdPhoto':
          _nationalIdPhoto = dataUrl;
          break;
        case 'driverLicensePhoto':
          _driverLicensePhoto = dataUrl;
          break;
        case 'tradeLicensePhoto':
          _tradeLicensePhoto = dataUrl;
          break;
        case 'tradeRegistrationCertificatePhoto':
          _tradeRegistrationCertificatePhoto = dataUrl;
          break;
      }
    });
  }

  String? _photoForKey(String key) {
    switch (key) {
      case 'nationalIdPhoto':
        return _nationalIdPhoto;
      case 'driverLicensePhoto':
        return _driverLicensePhoto;
      case 'tradeLicensePhoto':
        return _tradeLicensePhoto;
      case 'tradeRegistrationCertificatePhoto':
        return _tradeRegistrationCertificatePhoto;
      default:
        return null;
    }
  }

  String _textValueForKey(String key) {
    switch (key) {
      case 'tinNumber':
        return _tinNumberController.text.trim();
      case 'libre':
        return _libreController.text.trim();
      case 'vehiclePlateNumber':
        return _vehiclePlateController.text.trim();
      default:
        return '';
    }
  }

  List<String> _missingRequirements() {
    final requirements = VerificationAccess.requiredRequirements(_userType);
    final missing = <String>[];

    for (final item in requirements) {
      switch (item.kind) {
        case VerificationRequirementKind.number:
        case VerificationRequirementKind.text:
          if (_textValueForKey(item.key).isEmpty) {
            missing.add(item.label);
          }
          break;
        case VerificationRequirementKind.photo:
          if ((_photoForKey(item.key) ?? '').trim().isEmpty) {
            missing.add(item.label);
          }
          break;
      }
    }

    return missing;
  }

  Future<void> _save({required bool submitForReview}) async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('We could not find the current account.')),
      );
      return;
    }

    if (submitForReview) {
      final missing = _missingRequirements();
      if (missing.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please complete these first: ${missing.join(', ')}.',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await BackendHttp.request(
        path: '/api/users/$userId/verification-documents',
        method: 'PUT',
        body: {
          'tinNumber': _tinNumberController.text.trim(),
          'libre': _libreController.text.trim(),
          'vehiclePlateNumber': _vehiclePlateController.text.trim(),
          'nationalIdPhoto': _nationalIdPhoto,
          'driverLicensePhoto': _driverLicensePhoto,
          'tradeLicensePhoto': _tradeLicensePhoto,
          'tradeRegistrationCertificatePhoto':
              _tradeRegistrationCertificatePhoto,
          'submitForReview': submitForReview,
        },
      );
      await _authService.restoreSession();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            submitForReview
                ? 'Verification sent for admin approval.'
                : 'Verification progress saved.',
          ),
        ),
      );

      if (widget.isPostSignupFlow) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const Home()),
          (route) => false,
        );
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ErrorHandler.getMessage(error))));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  List<VerificationRequirement> _requirementsOfKind(
    VerificationRequirementKind kind,
  ) {
    return VerificationAccess.requiredRequirements(
      _userType,
    ).where((item) => item.kind == kind).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final numberRequirements = _requirementsOfKind(
      VerificationRequirementKind.number,
    );
    final textRequirements = _requirementsOfKind(
      VerificationRequirementKind.text,
    );
    final photoRequirements = _requirementsOfKind(
      VerificationRequirementKind.photo,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isPostSignupFlow ? 'Finish verification' : 'Verification',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppPalette.heroGradient,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isPostSignupFlow
                          ? 'Complete these details before restricted actions'
                          : 'Keep your verification ready',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _userType == 'Driver'
                          ? 'You can keep browsing now. Bidding unlocks after your TIN number, driver details, and photos are approved.'
                          : 'You can keep browsing now. Posting unlocks after your TIN number and business photos are approved.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: VerificationAccess.requiredDocuments(
                        _userType,
                      ).map((doc) => _HeroChip(label: doc)).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _StatusNotice(
                userType: _userType,
                status: _verificationStatus,
                note: _verificationNote,
              ),
              const SizedBox(height: 16),
              if (numberRequirements.isNotEmpty) ...[
                const _SectionHeader(
                  title: 'Number fields',
                  subtitle: 'Fill in the numbered business details first.',
                ),
                const SizedBox(height: 10),
                _FormCard(
                  child: Column(
                    children: numberRequirements
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextField(
                              controller: _tinNumberController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: item.label,
                                prefixIcon: const Icon(Icons.pin_outlined),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (textRequirements.isNotEmpty) ...[
                const _SectionHeader(
                  title: 'Text details',
                  subtitle:
                      'Add the vehicle and registration details exactly as written.',
                ),
                const SizedBox(height: 10),
                _FormCard(
                  child: Column(
                    children: [
                      if (textRequirements.any((item) => item.key == 'libre'))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextField(
                            controller: _libreController,
                            decoration: const InputDecoration(
                              labelText: 'Libre',
                              prefixIcon: Icon(Icons.description_outlined),
                            ),
                          ),
                        ),
                      if (textRequirements.any(
                        (item) => item.key == 'vehiclePlateNumber',
                      ))
                        TextField(
                          controller: _vehiclePlateController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle plate number',
                            prefixIcon: Icon(Icons.local_shipping_outlined),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const _SectionHeader(
                title: 'Photo uploads',
                subtitle:
                    'Use clear photos that are easy for the admin to read.',
              ),
              const SizedBox(height: 10),
              ...photoRequirements.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _DocumentCard(
                    title: item.label,
                    subtitle: _photoSubtitle(item.key, _userType),
                    imageSource: _photoForKey(item.key),
                    onPick: () => _pickPhoto(item.key),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppPalette.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark
                        ? AppPalette.darkOutline
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Simple path',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 10),
                    _ChecklistRow(text: 'Fill in the number fields first.'),
                    _ChecklistRow(
                      text:
                          'Add the remaining text details if your account needs them.',
                    ),
                    _ChecklistRow(
                      text:
                          'Upload the photos and submit once everything looks complete.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving
                      ? null
                      : () => _save(submitForReview: true),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _verificationStatus == 'rejected'
                              ? 'Resubmit for approval'
                              : 'Submit for approval',
                        ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => _save(submitForReview: false),
                  child: Text(
                    widget.isPostSignupFlow
                        ? 'Finish later'
                        : 'Save and continue later',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _photoSubtitle(String key, String userType) {
    switch (key) {
      case 'nationalIdPhoto':
        return 'Required for every account before restricted actions.';
      case 'driverLicensePhoto':
        return 'Required for driver accounts before bidding on loads.';
      case 'tradeLicensePhoto':
        return userType == 'Driver'
            ? 'Required to approve driver business verification.'
            : 'Required to approve cargo business verification.';
      case 'tradeRegistrationCertificatePhoto':
        return 'Required for cargo accounts before posting loads.';
      default:
        return 'Upload a clear image.';
    }
  }
}

class _StatusNotice extends StatelessWidget {
  final String userType;
  final String status;
  final String? note;

  const _StatusNotice({
    required this.userType,
    required this.status,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final normalizedStatus = VerificationAccess.normalizeStatus(status);
    final color = switch (normalizedStatus) {
      'approved' => const Color(0xFF4F8A69),
      'submitted' => const Color(0xFFC28C5A),
      'rejected' => const Color(0xFFB35C4B),
      _ => const Color(0xFF5B8C85),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(((isDark ? 0.24 : 0.10) * 255).round()),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withAlpha((0.35 * 255).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            VerificationAccess.statusTitle(status),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            VerificationAccess.statusDescription(
              userType: userType,
              status: status,
              note: note,
            ),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppPalette.darkTextSoft
                : Colors.black54,
          ),
        ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  final Widget child;

  const _FormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? AppPalette.darkOutline : const Color(0xFFE5E7EB),
        ),
      ),
      child: child,
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageSource;
  final VoidCallback onPick;

  const _DocumentCard({
    required this.title,
    required this.subtitle,
    required this.imageSource,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage = (imageSource ?? '').trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppPalette.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppPalette.darkOutline : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark ? AppPalette.darkTextSoft : Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            width: double.infinity,
            child: DocumentImage(source: imageSource),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(hasImage ? 'Replace photo' : 'Upload photo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final String text;

  const _ChecklistRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle_outline, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String label;

  const _HeroChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
