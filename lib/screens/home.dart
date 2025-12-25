import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '/screens/player.dart';
import '../config/app_config.dart';
import '../domain/entities/channel.dart';
import '../provider/channels_provider.dart';
import 'home/tv_home_layout.dart';
import 'home/tv_widgets.dart';

class Home extends StatefulWidget {
  final ChannelsProvider? provider;
  final bool autoLaunchPlayer;

  const Home({
    super.key,
    this.provider,
    this.autoLaunchPlayer = true,
  });

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool get _isTv => AppConfig.isTv;
  List<Channel> channels = [];
  List<Channel> filteredChannels = [];
  TextEditingController searchController = TextEditingController();
  late final ChannelsProvider channelsProvider;
  String? _appVersion;
  bool _isLoading = true;
  Timer? _debounceTimer;
  bool _autoOpened = false;
  bool _isReordering = false;
  bool _isLaunchingPlayer = false;
  Future<List<Channel>>? _remoteChannelsFuture;
  final ScrollController _tvScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    channelsProvider = widget.provider ?? ChannelsProvider();
    _loadAppVersion();
    fetchData();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) {
        return;
      }
      setState(() {
        _appVersion = '${info.version}+${info.buildNumber}';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _appVersion = null;
      });
    }
  }

  Future<void> fetchData() async {
    try {
      final data = await channelsProvider.fetchM3UFile();
      final shouldAutoOpen =
          !_autoOpened && data.isNotEmpty && widget.autoLaunchPlayer;
      setState(() {
        channels = data;
        filteredChannels = data;
        _isLoading = false;
        _isLaunchingPlayer = shouldAutoOpen;
      });
      if (shouldAutoOpen) {
        _autoOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Player(
                channels: channels,
                initialIndex: 0,
              ),
            ),
          ).then((_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _isLaunchingPlayer = false;
              _isLoading = false;
            });
          });
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('There was a problem finding the data'),
        ),
      );
    }
  }

  void filterChannels(String query) async {
    if (_isReordering) {
      return;
    }
    if (_debounceTimer != null) {
      _debounceTimer!.cancel();
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final filteredData = channelsProvider.filterChannels(query);
      setState(() {
        filteredChannels = filteredData;
      });
    });
  }

  Future<void> _showAddChannelDialog() async {
    if (_isTv) {
      await _showAddChannelDialogTv();
      return;
    }
    await _showAddChannelDialogMobile();
  }

  Future<void> _showAddChannelDialogMobile() async {
    _remoteChannelsFuture ??= channelsProvider.fetchRemoteChannels();
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
                future: _remoteChannelsFuture,
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
                  final remoteChannels = snapshot.data ?? [];
                  final lowerQuery = query.toLowerCase();
                  final existingKeys = channels
                      .map((channel) =>
                          channelsProvider.normalizeName(channel.name))
                      .where((key) => key.isNotEmpty)
                      .toSet();
                  final filtered = remoteChannels.where((channel) {
                    final key = channelsProvider.normalizeName(channel.name);
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
                                  final key = channelsProvider
                                      .normalizeName(channel.name);
                                  final selected = selectedKeys.contains(key);
                                  return ListTile(
                                    leading: Image.network(
                                      channel.logoUrl,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) {
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
                        setState(() {
                          selectedKeys.clear();
                        });
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
      return;
    }

    final remoteChannels = await _remoteChannelsFuture!;
    final existingKeys = channels
        .map((channel) => channelsProvider.normalizeName(channel.name))
        .where((key) => key.isNotEmpty)
        .toSet();
    final toAdd = remoteChannels.where((channel) {
      final key = channelsProvider.normalizeName(channel.name);
      return key.isNotEmpty &&
          selectedKeys.contains(key) &&
          !existingKeys.contains(key);
    }).toList();
    if (toAdd.isEmpty) {
      return;
    }

    setState(() {
      channels.addAll(toAdd);
      if (_isReordering || searchController.text.isEmpty) {
        filteredChannels = channels;
      } else {
        filteredChannels =
            channelsProvider.filterChannels(searchController.text);
      }
    });

    await channelsProvider.saveChannelOrder(channels);
  }

  Future<void> _showAddChannelDialogTv() async {
    _remoteChannelsFuture ??= channelsProvider.fetchRemoteChannels();
    String query = '';
    final selectedKeys = <String>{};
    final searchController = TextEditingController();
    final scrollController = ScrollController();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return TvDialogFrame(
            title: 'Add Channels',
            actions: [
              TvActionButton(
                label: 'Cancel',
                onActivate: () => Navigator.pop(context),
              ),
              TvActionButton(
                label: 'Clear',
                onActivate: selectedKeys.isEmpty
                    ? null
                    : () {
                        setState(selectedKeys.clear);
                      },
              ),
              TvActionButton(
                label: selectedKeys.isEmpty
                    ? 'Add'
                    : 'Add (${selectedKeys.length})',
                primary: true,
                onActivate:
                    selectedKeys.isEmpty ? null : () => Navigator.pop(context),
              ),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                    controller: searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search channels...',
                      filled: true,
                      fillColor: Colors.black.withAlpha(40),
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.white70),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            BorderSide(color: Colors.white.withAlpha(30)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            BorderSide(color: Colors.white.withAlpha(30)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide:
                            BorderSide(color: Colors.white.withAlpha(120)),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                    onChanged: (value) {
                      setState(() {
                        query = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 360,
                  child: FutureBuilder<List<Channel>>(
                    future: _remoteChannelsFuture,
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
                      final remoteChannels = snapshot.data ?? [];
                      final lowerQuery = query.toLowerCase();
                      final existingKeys = channels
                          .map((channel) =>
                              channelsProvider.normalizeName(channel.name))
                          .where((key) => key.isNotEmpty)
                          .toSet();
                      final filtered = remoteChannels.where((channel) {
                        final key =
                            channelsProvider.normalizeName(channel.name);
                        if (existingKeys.contains(key)) {
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
                        controller: scrollController,
                        thumbVisibility: true,
                        child: ListView.separated(
                          controller: scrollController,
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final channel = filtered[index];
                            final key =
                                channelsProvider.normalizeName(channel.name);
                            final selected = selectedKeys.contains(key);
                            return TvChannelSelectTile(
                              channel: channel,
                              selected: selected,
                              onToggle: () {
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

    searchController.dispose();
    scrollController.dispose();

    if (selectedKeys.isEmpty) {
      return;
    }

    final remoteChannels = await _remoteChannelsFuture!;
    final existingKeys = channels
        .map((channel) => channelsProvider.normalizeName(channel.name))
        .where((key) => key.isNotEmpty)
        .toSet();
    final toAdd = remoteChannels.where((channel) {
      final key = channelsProvider.normalizeName(channel.name);
      return key.isNotEmpty &&
          selectedKeys.contains(key) &&
          !existingKeys.contains(key);
    }).toList();
    if (toAdd.isEmpty) {
      return;
    }

    setState(() {
      channels.addAll(toAdd);
      filteredChannels = channels;
    });

    await channelsProvider.saveChannelOrder(channels);
  }

  Future<void> _showManageChannelsDialogTv() async {
    if (channels.isEmpty) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, dialogSetState) {
          Future<void> moveChannel(int from, int to) async {
            if (from < 0 || from >= channels.length) {
              return;
            }
            if (to < 0 || to >= channels.length) {
              return;
            }
            if (!mounted) {
              return;
            }
            setState(() {
              final item = channels.removeAt(from);
              channels.insert(to, item);
              filteredChannels = channels;
            });
            dialogSetState(() {});
            await channelsProvider.saveChannelOrder(channels);
          }

          Future<void> removeChannel(Channel channel) async {
            final confirmed = await _confirmRemoveChannelTv(channel);
            if (!confirmed) {
              return;
            }
            if (!mounted) {
              return;
            }
            setState(() {
              channels.removeWhere((entry) =>
                  channelsProvider.normalizeName(entry.name) ==
                  channelsProvider.normalizeName(channel.name));
              filteredChannels = channels;
            });
            dialogSetState(() {});
            await channelsProvider.removeCustomChannelByName(channel.name);
            await channelsProvider.saveChannelOrder(channels);
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
            child: SizedBox(
              height: 420,
              child: ListView.separated(
                itemCount: channels.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final channel = channels[index];
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
                          onActivate: index == channels.length - 1
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
          );
        },
      ),
    );
  }

  Future<bool> _confirmRemoveChannelTv(Channel channel) async {
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

  Future<void> _toggleReorderMode() async {
    _debounceTimer?.cancel();
    setState(() {
      _isReordering = !_isReordering;
      if (_isReordering) {
        searchController.clear();
        filteredChannels = channels;
      } else if (searchController.text.isEmpty) {
        filteredChannels = channels;
      } else {
        filteredChannels =
            channelsProvider.filterChannels(searchController.text);
      }
    });
  }

  Future<void> _removeChannel(Channel channel) async {
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
    if (confirmed != true) {
      return;
    }

    final key = channelsProvider.normalizeName(channel.name);
    setState(() {
      channels.removeWhere(
        (entry) => channelsProvider.normalizeName(entry.name) == key,
      );
      if (_isReordering || searchController.text.isEmpty) {
        filteredChannels = channels;
      } else {
        filteredChannels =
            channelsProvider.filterChannels(searchController.text);
      }
    });

    await channelsProvider.removeCustomChannelByName(channel.name);
    await channelsProvider.saveChannelOrder(channels);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    searchController.dispose();
    _tvScrollController.dispose();
    super.dispose();
  }

  void _launchPlayer(List<Channel> list, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Player(
          channels: list,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLaunchingPlayer) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Image.asset(
            'assets/images/tv-icon.png',
            width: 140,
            height: 140,
          ),
        ),
      );
    }
    if (_isTv) {
      return TvHomeLayout(
        channels: filteredChannels,
        isLoading: _isLoading,
        version: _appVersion,
        flavor: AppConfig.target,
        onAddChannel: _showAddChannelDialog,
        onManageChannels: _showManageChannelsDialogTv,
        onRefresh: fetchData,
        onChannelSelected: (index) => _launchPlayer(filteredChannels, index),
        scrollController: _tvScrollController,
      );
    }
    final List<Widget> sections = [];
    if (!_isTv) {
      sections.add(
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: searchController,
            enabled: !_isReordering,
            onChanged: (value) {
              filterChannels(value);
            },
            decoration: const InputDecoration(
              labelText: 'Search',
              hintText: 'Search channels...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
      );
    }
    sections.add(
      Expanded(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _isReordering
                ? ReorderableListView.builder(
                    itemCount: channels.length,
                    onReorder: (oldIndex, newIndex) async {
                      setState(() {
                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }
                        final item = channels.removeAt(oldIndex);
                        channels.insert(newIndex, item);
                        filteredChannels = channels;
                      });
                      await channelsProvider.saveChannelOrder(channels);
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
                  )
                : ListView.builder(
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
                          onPressed: () => _removeChannel(channel),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Player(
                                channels: filteredChannels,
                                initialIndex: index,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Channel List'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _showAddChannelDialog,
            icon: const Icon(Icons.add),
            tooltip: 'Add channel',
          ),
          IconButton(
            onPressed: _isLoading ? null : _toggleReorderMode,
            icon: Icon(_isReordering ? Icons.check : Icons.reorder),
            tooltip: _isReordering ? 'Done' : 'Reorder channels',
          ),
        ],
      ),
      body: Column(
        children: sections,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'v${_appVersion ?? '...'} • ${AppConfig.target} (c) ${DateTime.now().year}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
    );
  }
}
