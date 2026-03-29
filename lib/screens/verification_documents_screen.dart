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

  const VerificationDocumentsScreen({
    super.key,
    this.isPostSignupFlow = false,
  });

  @override
  State<VerificationDocumentsScreen> createState() =>
      _VerificationDocumentsScreenState();
}

class _VerificationDocumentsScreenState
    extends State<VerificationDocumentsScreen> {
  final BackendAuthService _authService = BackendAuthService();
  final ImagePicker _imagePicker = ImagePicker();

  String? _userId;
  String _userType = 'Cargo';
  String _verificationStatus = 'not_submitted';
  String? _verificationNote;
  String? _nationalIdPhoto;
  String? _driverLicensePhoto;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      await _authService.restoreSession();
      final user = await _authService.getStoredUserMap();
      if (!mounted) return;
      setState(() {
        _userId = user?['id']?.toString();
        _userType = (user?['userType'] ?? 'Cargo').toString();
        _verificationStatus =
            VerificationAccess.normalizeStatus(user?['verificationStatus']?.toString());
        _verificationNote = user?['verificationNote']?.toString();
        _nationalIdPhoto = user?['idPhoto']?.toString();
        _driverLicensePhoto = user?['licenseNumberPhoto']?.toString();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pickDocument({required bool driverLicense}) async {
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
      if (driverLicense) {
        _driverLicensePhoto = dataUrl;
      } else {
        _nationalIdPhoto = dataUrl;
      }
    });
  }

  Future<void> _save({required bool submitForReview}) async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('We could not find the current account.')),
      );
      return;
    }

    if (submitForReview && (_nationalIdPhoto == null || _nationalIdPhoto!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('National ID is required before submission.')),
      );
      return;
    }

    if (submitForReview &&
        _userType == 'Driver' &&
        (_driverLicensePhoto == null || _driverLicensePhoto!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver\'s license is required before submission.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await BackendHttp.request(
        path: '/api/users/$userId/verification-documents',
        method: 'PUT',
        body: {
          'nationalIdPhoto': _nationalIdPhoto,
          'driverLicensePhoto': _driverLicensePhoto,
          'submitForReview': submitForReview,
        },
      );
      await _authService.restoreSession();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            submitForReview
                ? 'Documents submitted for admin approval.'
                : 'You can finish verification later from your profile.',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.getMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final requiredDocs = VerificationAccess.requiredDocuments(_userType);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isPostSignupFlow ? 'Verify your account' : 'Verification'),
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
                          ? 'One more step before restricted actions'
                          : 'Keep your verification up to date',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You can keep exploring the app right away. Admin approval is only required before posting loads as cargo or placing bids as a driver.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: requiredDocs
                          .map((doc) => _HeroChip(label: doc))
                          .toList(),
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
              _DocumentCard(
                title: 'National ID',
                subtitle: 'Required for every account before restricted marketplace actions.',
                imageSource: _nationalIdPhoto,
                onPick: () => _pickDocument(driverLicense: false),
              ),
              if (_userType == 'Driver') ...[
                const SizedBox(height: 14),
                _DocumentCard(
                  title: 'Driver\'s license',
                  subtitle: 'Required for driver accounts before bidding on loads.',
                  imageSource: _driverLicensePhoto,
                  onPick: () => _pickDocument(driverLicense: true),
                ),
              ],
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppPalette.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark ? AppPalette.darkOutline : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What happens next',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    const _ChecklistRow(
                      text: 'Upload the required documents from this screen or later from your profile.',
                    ),
                    const _ChecklistRow(
                      text: 'Submit for admin review when you are ready.',
                    ),
                    const _ChecklistRow(
                      text: 'Until approval, you can browse feeds, loads, and profiles normally.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : () => _save(submitForReview: true),
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
                  onPressed: _saving ? null : () => _save(submitForReview: false),
                  child: Text(widget.isPostSignupFlow ? 'Upload later' : 'Save and continue later'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      'approved' => const Color(0xFF16A34A),
      'submitted' => const Color(0xFFF59E0B),
      'rejected' => const Color(0xFFDC2626),
      _ => const Color(0xFF0EA5E9),
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            VerificationAccess.statusDescription(
              userType: userType,
              status: status,
              note: note,
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
        ],
      ),
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(hasImage ? 'Replace image' : 'Upload image'),
                ),
              ),
            ],
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
