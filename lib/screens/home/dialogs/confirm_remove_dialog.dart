import 'package:flutter/material.dart';

import '../../../domain/entities/channel.dart';

Future<bool> showConfirmRemoveDialog(
  BuildContext context,
  Channel channel,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Remove Channel'),
        content: Text('Remove "${channel.name}" from your playlist?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
