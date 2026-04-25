import 'package:flutter/material.dart';

import 'track_loads_screen.dart';

class MyLoadsScreen extends StatelessWidget {
  final String cargoUserId;

  const MyLoadsScreen({super.key, required this.cargoUserId});

  @override
  Widget build(BuildContext context) {
    return const TrackLoadsScreen(showBack: true);
  }
}
