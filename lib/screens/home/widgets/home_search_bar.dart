import 'package:flutter/material.dart';

class HomeSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const HomeSearchBar({
    required this.controller,
    required this.enabled,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: controller,
        enabled: enabled,
        onChanged: onChanged,
        decoration: const InputDecoration(
          labelText: 'Search',
          hintText: 'Search channels...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}
