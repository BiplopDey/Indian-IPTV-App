import 'package:flutter/material.dart';

class HomeLaunchSplash extends StatelessWidget {
  final String assetPath;

  const HomeLaunchSplash({
    required this.assetPath,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Image.asset(
          assetPath,
          width: 140,
          height: 140,
        ),
      ),
    );
  }
}
