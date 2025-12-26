import 'package:flutter/material.dart';

import '../../../domain/entities/channel.dart';

class HomeChannelList extends StatelessWidget {
  final bool isLoading;
  final bool isReordering;
  final List<Channel> channels;
  final List<Channel> filteredChannels;
  final Future<void> Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<Channel> onRemoveChannel;
  final void Function(int index) onChannelSelected;

  const HomeChannelList({
    required this.isLoading,
    required this.isReordering,
    required this.channels,
    required this.filteredChannels,
    required this.onReorder,
    required this.onRemoveChannel,
    required this.onChannelSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    if (isReordering) {
      return ReorderableListView.builder(
        itemCount: channels.length,
        onReorder: (oldIndex, newIndex) {
          onReorder(oldIndex, newIndex);
        },
        itemBuilder: (context, index) {
          final channel = channels[index];
          return ListTile(
            key: ValueKey(channel.name),
            leading: Image.network(
              channel.logoUrl,
              width: 50,
              height: 50,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Image.asset(
                  'assets/images/tv-icon.png',
                  width: 50,
                  height: 50,
                  fit: BoxFit.contain,
                );
              },
            ),
            title: Text(channel.name),
          );
        },
      );
    }
    return ListView.builder(
      itemCount: filteredChannels.length,
      itemBuilder: (context, index) {
        final channel = filteredChannels[index];
        return ListTile(
          leading: Image.network(
            channel.logoUrl,
            width: 50,
            height: 50,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                'assets/images/tv-icon.png',
                width: 50,
                height: 50,
                fit: BoxFit.contain,
              );
            },
          ),
          title: Text(channel.name),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove channel',
            onPressed: () => onRemoveChannel(channel),
          ),
          onTap: () => onChannelSelected(index),
        );
      },
    );
  }
}
