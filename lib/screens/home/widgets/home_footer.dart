import 'package:flutter/material.dart';

class HomeFooter extends StatelessWidget {
  final String? version;
  final String flavor;

  const HomeFooter({
    required this.version,
    required this.flavor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          'v${version ?? '...'} • $flavor (c) ${DateTime.now().year}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
