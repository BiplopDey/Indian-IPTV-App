import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '/screens/player.dart';
import '../domain/entities/channel.dart';
import '../provider/channels_provider.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final bool _isTv =
      const String.fromEnvironment('TARGET', defaultValue: 'mobile') == 'tv';
  List<Channel> channels = [];
  List<Channel> filteredChannels = [];
  TextEditingController searchController = TextEditingController();
  final ChannelsProvider channelsProvider = ChannelsProvider();
  String? _appVersion;
  bool _isLoading = true;
  Timer? _debounceTimer;
  bool _autoOpened = false;
  bool _isReordering = false;
  bool _isLaunchingPlayer = false;
  Future<List<Channel>>? _remoteChannelsFuture;

  @override
  void initState() {
    super.initState();
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
      final shouldAutoOpen = !_autoOpened && data.isNotEmpty;
      setState(() {
        channels = data;
        filteredChannels = data;
        _isLoading = !shouldAutoOpen;
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('There was a problem finding the data')));
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
                onPressed: selectedKeys.isEmpty
                    ? null
                    : () => Navigator.pop(context),
                child: Text(
                  selectedKeys.isEmpty
                      ? 'Add'
                      : 'Add (${selectedKeys.length})',
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
    super.dispose();
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
            'v${_appVersion ?? '...'} (c) ${DateTime.now().year}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
    );
  }
}
