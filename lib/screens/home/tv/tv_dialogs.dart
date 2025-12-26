import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/entities/channel.dart';
import 'tv_widgets.dart';

Future<List<Channel>> showTvAddChannelsDialog({
  required BuildContext context,
  required Future<List<Channel>> remoteChannels,
  required List<Channel> existingChannels,
  required String Function(String) normalizeName,
}) async {
  final selectedKeys = await showDialog<Set<String>>(
    context: context,
    builder: (dialogContext) => _TvAddChannelsDialog(
      remoteChannels: remoteChannels,
      existingChannels: existingChannels,
      normalizeName: normalizeName,
    ),
  );

  if (selectedKeys == null || selectedKeys.isEmpty) {
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

class _TvAddChannelsDialog extends StatefulWidget {
  final Future<List<Channel>> remoteChannels;
  final List<Channel> existingChannels;
  final String Function(String) normalizeName;

  const _TvAddChannelsDialog({
    required this.remoteChannels,
    required this.existingChannels,
    required this.normalizeName,
  });

  @override
  State<_TvAddChannelsDialog> createState() => _TvAddChannelsDialogState();
}

class _TvAddChannelsDialogState extends State<_TvAddChannelsDialog> {
  final Set<String> _selectedKeys = <String>{};
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final Set<String> _existingKeys = widget.existingChannels
      .map((channel) => widget.normalizeName(channel.name))
      .where((key) => key.isNotEmpty)
      .toSet();
  late final Future<List<Channel>> _remoteFuture = widget.remoteChannels;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleCancel() {
    FocusScope.of(context).unfocus();
    Navigator.pop(context);
  }

  void _handleClear() {
    setState(_selectedKeys.clear);
  }

  void _handleAdd() {
    FocusScope.of(context).unfocus();
    Navigator.pop(context, Set<String>.from(_selectedKeys));
  }

  @override
  Widget build(BuildContext context) {
    return TvDialogFrame(
      title: 'Add Channels',
      actions: [
        TvActionButton(
          label: 'Cancel',
          onActivate: _handleCancel,
        ),
        TvActionButton(
          label: 'Clear',
          onActivate: _selectedKeys.isEmpty ? null : _handleClear,
        ),
        TvActionButton(
          label:
              _selectedKeys.isEmpty ? 'Add' : 'Add (${_selectedKeys.length})',
          primary: true,
          onActivate: _selectedKeys.isEmpty ? null : _handleAdd,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.arrowDown) {
                FocusScope.of(context).nextFocus();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search channels...',
                filled: true,
                fillColor: Colors.black.withAlpha(40),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withAlpha(30)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withAlpha(30)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withAlpha(120)),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                setState(() {
                  _query = value;
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Channel>>(
              future: _remoteFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Unable to load channels.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }
                final remoteList = snapshot.data ?? [];
                final lowerQuery = _query.toLowerCase();
                final filtered = remoteList.where((channel) {
                  final key = widget.normalizeName(channel.name);
                  if (_existingKeys.contains(key)) {
                    return false;
                  }
                  if (lowerQuery.isEmpty) {
                    return true;
                  }
                  return channel.name.toLowerCase().contains(lowerQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No channels found.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: ListView.separated(
                    controller: _scrollController,
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final channel = filtered[index];
                      final key = widget.normalizeName(channel.name);
                      final selected = _selectedKeys.contains(key);
                      return TvChannelSelectTile(
                        channel: channel,
                        selected: selected,
                        onToggle: () {
                          setState(() {
                            if (selected) {
                              _selectedKeys.remove(key);
                            } else {
                              _selectedKeys.add(key);
                            }
                          });
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showTvManageChannelsDialog({
  required BuildContext context,
  required List<Channel> channels,
  required Future<void> Function(int from, int to) onMove,
  required Future<void> Function(Channel channel) onRemove,
}) async {
  if (channels.isEmpty) {
    return;
  }

  final localChannels = List<Channel>.from(channels);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, dialogSetState) {
        Future<void> moveChannel(int from, int to) async {
          if (from < 0 || from >= localChannels.length) {
            return;
          }
          if (to < 0 || to >= localChannels.length) {
            return;
          }
          final item = localChannels.removeAt(from);
          localChannels.insert(to, item);
          dialogSetState(() {});
          await onMove(from, to);
        }

        Future<void> removeChannel(Channel channel) async {
          final confirmed = await showTvConfirmRemoveDialog(context, channel);
          if (!confirmed) {
            return;
          }
          localChannels.removeWhere((entry) => entry.name == channel.name);
          dialogSetState(() {});
          await onRemove(channel);
        }

        return TvDialogFrame(
          title: 'Manage Channels',
          actions: [
            TvActionButton(
              label: 'Done',
              primary: true,
              onActivate: () => Navigator.pop(context),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: ListView.separated(
                  itemCount: localChannels.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final channel = localChannels[index];
                    final group = channel.groupTitle.trim();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(45),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withAlpha(18)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(70),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: channel.logoUrl.trim().isEmpty
                                ? Image.asset(
                                    'assets/images/tv-icon.png',
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.contain,
                                  )
                                : Image.network(
                                    channel.logoUrl,
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Image.asset(
                                        'assets/images/tv-icon.png',
                                        width: 32,
                                        height: 32,
                                        fit: BoxFit.contain,
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  channel.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                if (group.isNotEmpty)
                                  Text(
                                    group,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          TvActionButton(
                            label: 'Up',
                            onActivate: index == 0
                                ? null
                                : () => moveChannel(index, index - 1),
                          ),
                          const SizedBox(width: 8),
                          TvActionButton(
                            label: 'Down',
                            onActivate: index == localChannels.length - 1
                                ? null
                                : () => moveChannel(index, index + 1),
                          ),
                          const SizedBox(width: 8),
                          TvActionButton(
                            label: 'Remove',
                            onActivate: () => removeChannel(channel),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Future<bool> showTvConfirmRemoveDialog(
  BuildContext context,
  Channel channel,
) async {
  bool confirmed = false;
  await showDialog<void>(
    context: context,
    builder: (context) {
      return TvDialogFrame(
        title: 'Remove Channel',
        actions: [
          TvActionButton(
            label: 'Cancel',
            onActivate: () => Navigator.pop(context),
          ),
          TvActionButton(
            label: 'Remove',
            primary: true,
            onActivate: () {
              confirmed = true;
              Navigator.pop(context);
            },
          ),
        ],
        child: Text(
          'Remove "${channel.name}" from your playlist?',
          style: const TextStyle(color: Colors.white70),
        ),
      );
    },
  );
  return confirmed;
}
