import 'package:flutter/material.dart';

import '../../../domain/entities/channel.dart';

Future<List<Channel>> showMobileAddChannelsDialog({
  required BuildContext context,
  required Future<List<Channel>> remoteChannels,
  required List<Channel> existingChannels,
  required String Function(String) normalizeName,
}) async {
  String query = '';
  final selectedKeys = <String>{};

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('Add Channels'),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder<List<Channel>>(
              future: remoteChannels,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return const Text('Unable to load channels.');
                }
                final remoteList = snapshot.data ?? [];
                final lowerQuery = query.toLowerCase();
                final existingKeys = existingChannels
                    .map((channel) => normalizeName(channel.name))
                    .where((key) => key.isNotEmpty)
                    .toSet();
                final filtered = remoteList.where((channel) {
                  final key = normalizeName(channel.name);
                  if (existingKeys.contains(key)) {
                    return false;
                  }
                  if (lowerQuery.isEmpty) {
                    return true;
                  }
                  return channel.name.toLowerCase().contains(lowerQuery);
                }).toList();
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Search',
                        hintText: 'Search channels...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          query = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 360,
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text('No channels found.'),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final channel = filtered[index];
                                final key = normalizeName(channel.name);
                                final selected = selectedKeys.contains(key);
                                return ListTile(
                                  leading: Image.network(
                                    channel.logoUrl,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Image.asset(
                                        'assets/images/tv-icon.png',
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.contain,
                                      );
                                    },
                                  ),
                                  title: Text(channel.name),
                                  trailing: Checkbox(
                                    value: selected,
                                    onChanged: (_) {
                                      setState(() {
                                        if (selected) {
                                          selectedKeys.remove(key);
                                        } else {
                                          selectedKeys.add(key);
                                        }
                                      });
                                    },
                                  ),
                                  onTap: () {
                                    setState(() {
                                      if (selected) {
                                        selectedKeys.remove(key);
                                      } else {
                                        selectedKeys.add(key);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: selectedKeys.isEmpty
                  ? null
                  : () {
                      setState(selectedKeys.clear);
                    },
              child: const Text('Clear selection'),
            ),
            ElevatedButton(
              onPressed:
                  selectedKeys.isEmpty ? null : () => Navigator.pop(context),
              child: Text(
                selectedKeys.isEmpty ? 'Add' : 'Add (${selectedKeys.length})',
              ),
            ),
          ],
        );
      },
    ),
  );

  if (selectedKeys.isEmpty) {
    return const [];
  }

  final remoteList = await remoteChannels;
  final existingKeys = existingChannels
      .map((channel) => normalizeName(channel.name))
      .where((key) => key.isNotEmpty)
      .toSet();
  return remoteList.where((channel) {
    final key = normalizeName(channel.name);
    return key.isNotEmpty &&
        selectedKeys.contains(key) &&
        !existingKeys.contains(key);
  }).toList();
}
