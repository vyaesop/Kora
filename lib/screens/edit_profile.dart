import 'package:flutter/material.dart';

import '../model/user.dart';
import '../app_localizations.dart';

class EditProfile extends StatelessWidget {
  final UserModel user;
  final dynamic panelController;

  const EditProfile({
    super.key,
    required this.user,
    required this.panelController,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.tr('editProfile'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('${localizations.tr('nameLabel')}: ${user.name}'),
            Text('${localizations.tr('usernameLabel')}: ${user.username}'),
            Text('${localizations.tr('typeLabel')}: ${user.userType}'),
            const SizedBox(height: 16),
            Text(
              localizations.tr('profileEditPlaceholder'),
              style: const TextStyle(color: Colors.black54),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(localizations.tr('close')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

