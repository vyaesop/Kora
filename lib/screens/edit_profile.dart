import 'package:flutter/material.dart';

import '../model/user.dart';

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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit Profile',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('Name: ${user.name}'),
            Text('Username: ${user.username}'),
            Text('Type: ${user.userType}'),
            const SizedBox(height: 16),
            const Text(
              'Profile editing UI was missing and has been restored as a placeholder.',
              style: TextStyle(color: Colors.black54),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
