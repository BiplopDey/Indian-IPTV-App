import 'package:flutter/material.dart';

import '../../../config/app_config.dart';
import '../../../domain/entities/channel.dart';
import '../home_state.dart';
import 'home_channel_list.dart';
import 'home_footer.dart';
import 'home_search_bar.dart';

class MobileHomeLayout extends StatelessWidget {
  final HomeState state;
  final TextEditingController searchController;
  final VoidCallback onAddChannel;
  final VoidCallback onToggleReorder;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<Channel> onRemoveChannel;
  final void Function(int index) onChannelSelected;

  const MobileHomeLayout({
    required this.state,
    required this.searchController,
    required this.onAddChannel,
    required this.onToggleReorder,
    required this.onSearchChanged,
    required this.onReorder,
    required this.onRemoveChannel,
    required this.onChannelSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Channel List'),
        actions: [
          IconButton(
            onPressed: state.isLoading ? null : onAddChannel,
            icon: const Icon(Icons.add),
            tooltip: 'Add channel',
          ),
          IconButton(
            onPressed: state.isLoading ? null : onToggleReorder,
            icon: Icon(state.isReordering ? Icons.check : Icons.reorder),
            tooltip: state.isReordering ? 'Done' : 'Reorder channels',
          ),
        ],
      ),
      body: Column(
        children: [
          HomeSearchBar(
            controller: searchController,
            enabled: !state.isReordering,
            onChanged: onSearchChanged,
          ),
          Expanded(
            child: HomeChannelList(
              isLoading: state.isLoading,
              isReordering: state.isReordering,
              channels: state.channels,
              filteredChannels: state.filteredChannels,
              onReorder: onReorder,
              onRemoveChannel: onRemoveChannel,
              onChannelSelected: onChannelSelected,
            ),
          ),
        ],
      ),
      bottomNavigationBar: HomeFooter(
        version: state.appVersion,
        flavor: AppConfig.target,
      ),
    );
  }
}
