import 'package:flutter/material.dart';

import '/screens/player.dart';
import '../config/app_config.dart';
import '../domain/entities/channel.dart';
import '../provider/channels_provider.dart';
import 'home/app_version_loader.dart';
import 'home/dialogs/confirm_remove_dialog.dart';
import 'home/dialogs/mobile_add_channels_dialog.dart';
import 'home/home_channels_service.dart';
import 'home/home_controller.dart';
import 'home/home_state.dart';
import 'home/tv/tv_dialogs.dart';
import 'home/tv/tv_home_layout.dart';
import 'home/widgets/home_launch_splash.dart';
import 'home/widgets/mobile_home_layout.dart';

class Home extends StatefulWidget {
  final ChannelsProvider? provider;
  final HomeChannelsService? channelsService;
  final AppVersionLoader? versionLoader;
  final HomeController? controller;
  final bool autoLaunchPlayer;

  const Home({
    super.key,
    this.provider,
    this.channelsService,
    this.versionLoader,
    this.controller,
    this.autoLaunchPlayer = true,
  });

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool get _useTvLayout => AppConfig.useTvLayout();

  late final HomeController _controller;
  late final bool _ownsController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _tvScrollController = ScrollController();
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? _buildController();
    _ownsController = widget.controller == null;
    _controller.addListener(_handleControllerChange);
    _loadInitialData();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChange);
    if (_ownsController) {
      _controller.dispose();
    }
    _searchController.dispose();
    _tvScrollController.dispose();
    super.dispose();
  }

  HomeController _buildController() {
    final service = widget.channelsService ??
        ChannelsProviderService(widget.provider ?? ChannelsProvider());
    final versionLoader = widget.versionLoader ?? PackageInfoVersionLoader();
    return HomeController(
      channelsService: service,
      versionLoader: versionLoader,
      autoLaunchPlayer: widget.autoLaunchPlayer,
    );
  }

  Future<void> _loadInitialData() async {
    try {
      await _controller.initialize();
    } catch (_) {
      _showFetchError();
    }
  }

  void _handleControllerChange() {
    _syncSearchQuery(_controller.state);
    final pendingIndex = _controller.state.pendingLaunchIndex;
    if (pendingIndex != null && !_isNavigating) {
      _isNavigating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          _isNavigating = false;
          return;
        }
        _launchPlayer(_controller.state.channels, pendingIndex).then((_) {
          if (!mounted) {
            return;
          }
          _isNavigating = false;
          _controller.markLaunchHandled();
        });
      });
    }
  }

  void _syncSearchQuery(HomeState state) {
    if (_searchController.text == state.searchQuery) {
      return;
    }
    _searchController.value = TextEditingValue(
      text: state.searchQuery,
      selection: TextSelection.collapsed(offset: state.searchQuery.length),
    );
  }

  void _showFetchError() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('There was a problem finding the data'),
      ),
    );
  }

  Future<void> _refreshChannels() async {
    try {
      await _controller.refresh();
    } catch (_) {
      _showFetchError();
    }
  }

  Future<void> _handleAddChannels() async {
    try {
      final toAdd = await _showAddChannelsDialog();
      if (!mounted) {
        return;
      }
      await _controller.addChannels(toAdd);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showFetchError();
    }
  }

  Future<List<Channel>> _showAddChannelsDialog() {
    if (_useTvLayout) {
      return showTvAddChannelsDialog(
        context: context,
        remoteChannels: _controller.fetchRemoteChannels(),
        existingChannels: _controller.state.channels,
        normalizeName: _controller.normalizeName,
      );
    }
    return showMobileAddChannelsDialog(
      context: context,
      remoteChannels: _controller.fetchRemoteChannels(),
      existingChannels: _controller.state.channels,
      normalizeName: _controller.normalizeName,
    );
  }

  Future<void> _handleToggleReorder() async {
    _controller.toggleReorderMode();
    _syncSearchQuery(_controller.state);
  }

  Future<void> _handleRemoveChannel(Channel channel) async {
    final confirmed = await showConfirmRemoveDialog(context, channel);
    if (!mounted) {
      return;
    }
    if (!confirmed) {
      return;
    }
    await _controller.removeChannel(channel);
  }

  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    await _controller.moveChannel(oldIndex, newIndex);
  }

  Future<void> _handleManageChannelsTv() async {
    await showTvManageChannelsDialog(
      context: context,
      channels: _controller.state.channels,
      onMove: (from, to) => _controller.moveChannel(from, to),
      onRemove: (channel) => _controller.removeChannel(channel),
    );
  }

  Future<void> _launchPlayer(List<Channel> list, int index) {
    return Navigator.push(
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;
        if (state.isLaunchingPlayer) {
          return const HomeLaunchSplash(
            assetPath: 'assets/images/tv-icon.png',
          );
        }
        if (_useTvLayout) {
          return TvHomeLayout(
            channels: state.filteredChannels,
            isLoading: state.isLoading,
            version: state.appVersion,
            flavor: AppConfig.target,
            onAddChannel: _handleAddChannels,
            onManageChannels: _handleManageChannelsTv,
            onRefresh: _refreshChannels,
            onChannelSelected: (index) =>
                _launchPlayer(state.filteredChannels, index),
            scrollController: _tvScrollController,
          );
        }
        return MobileHomeLayout(
          state: state,
          searchController: _searchController,
          onAddChannel: _handleAddChannels,
          onToggleReorder: _handleToggleReorder,
          onSearchChanged: _controller.setSearchQuery,
          onReorder: _handleReorder,
          onRemoveChannel: _handleRemoveChannel,
          onChannelSelected: (index) =>
              _launchPlayer(state.filteredChannels, index),
        );
      },
    );
  }
}
