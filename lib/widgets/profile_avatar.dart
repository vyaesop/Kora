import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final IconData fallbackIcon;

  const ProfileAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 18,
    this.fallbackIcon = Icons.person,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = imageUrl?.trim() ?? '';
    if (trimmed.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade200,
        child: Icon(fallbackIcon, size: radius, color: Colors.grey.shade700),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade200,
      child: ClipOval(
        child: Image.network(
          trimmed,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            fallbackIcon,
            size: radius,
            color: Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}
