import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/channel.dart';
import 'app_version_loader.dart';
import 'home_channels_service.dart';
import 'home_state.dart';

class HomeController extends ChangeNotifier {
  HomeController({
    required HomeChannelsService channelsService,
    required AppVersionLoader versionLoader,
    required bool autoLaunchPlayer,
  })  : _channelsService = channelsService,
        _versionLoader = versionLoader,
        _autoLaunchPlayer = autoLaunchPlayer;

  final HomeChannelsService _channelsService;
  final AppVersionLoader _versionLoader;
  final bool _autoLaunchPlayer;

  HomeState _state = const HomeState.initial();
  Timer? _debounceTimer;
  Future<List<Channel>>? _remoteChannelsFuture;
  bool _autoOpened = false;

  HomeState get state => _state;

  String normalizeName(String value) => _channelsService.normalizeName(value);

  Future<void> initialize() async {
    await _loadAppVersion();
    await refresh(allowAutoLaunch: true);
  }

  Future<void> refresh({bool allowAutoLaunch = false}) async {
    _debounceTimer?.cancel();
    _setState(
      _state.copyWith(
        isLoading: true,
        isLaunchingPlayer: false,
        pendingLaunchIndex: null,
      ),
    );
    List<Channel> data;
    try {
      data = await _channelsService.fetchChannels();
    } catch (_) {
      _setState(
        _state.copyWith(
          isLoading: false,
          isLaunchingPlayer: false,
          pendingLaunchIndex: null,
        ),
      );
      rethrow;
    }
    final shouldLaunch =
        allowAutoLaunch && !_autoOpened && data.isNotEmpty && _autoLaunchPlayer;
    if (shouldLaunch) {
      _autoOpened = true;
    }
    final filtered = _applyFilter(
      query: _state.searchQuery,
      channels: data,
      isReordering: _state.isReordering,
    );
    _setState(
      _state.copyWith(
        channels: data,
        filteredChannels: filtered,
        isLoading: false,
        isLaunchingPlayer: shouldLaunch,
        pendingLaunchIndex: shouldLaunch ? 0 : null,
      ),
    );
  }

  void setSearchQuery(String query) {
    if (_state.isReordering) {
      return;
    }
    _debounceTimer?.cancel();
    _setState(_state.copyWith(searchQuery: query));
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final filtered = _applyFilter(
        query: query,
        channels: _state.channels,
        isReordering: _state.isReordering,
      );
      _setState(_state.copyWith(filteredChannels: filtered));
    });
  }

  void toggleReorderMode() {
    _debounceTimer?.cancel();
    final next = !_state.isReordering;
    final nextQuery = next ? '' : _state.searchQuery;
    final filtered = _applyFilter(
      query: nextQuery,
      channels: _state.channels,
      isReordering: next,
    );
    _setState(
      _state.copyWith(
        isReordering: next,
        searchQuery: nextQuery,
        filteredChannels: filtered,
      ),
    );
  }

  Future<List<Channel>> fetchRemoteChannels({bool forceRefresh = false}) {
    if (!forceRefresh && _remoteChannelsFuture != null) {
      return _remoteChannelsFuture!;
    }
    _remoteChannelsFuture =
        _channelsService.fetchRemoteChannels(forceRefresh: forceRefresh);
    return _remoteChannelsFuture!;
  }

  Future<void> addChannels(List<Channel> toAdd) async {
    if (toAdd.isEmpty) {
      return;
    }
    final updated = List<Channel>.from(_state.channels)..addAll(toAdd);
    await _setChannels(updated);
  }

  Future<void> moveChannel(int from, int to) async {
    if (from < 0 || from >= _state.channels.length) {
      return;
    }
    if (to < 0 || to >= _state.channels.length) {
      return;
    }
    final updated = List<Channel>.from(_state.channels);
    final item = updated.removeAt(from);
    updated.insert(to, item);
    await _setChannels(updated);
  }

  Future<void> removeChannel(Channel channel) async {
    final key = _channelsService.normalizeName(channel.name);
    if (key.isEmpty) {
      return;
    }
    await _channelsService.removeCustomChannelByName(channel.name);
    final updated = _state.channels
        .where((entry) => _channelsService.normalizeName(entry.name) != key)
        .toList();
    await _setChannels(updated);
  }

  void markLaunchHandled() {
    if (!_state.isLaunchingPlayer && _state.pendingLaunchIndex == null) {
      return;
    }
    _setState(
      _state.copyWith(
        isLaunchingPlayer: false,
        pendingLaunchIndex: null,
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAppVersion() async {
    final version = await _versionLoader.loadAppVersion();
    _setState(_state.copyWith(appVersion: version));
  }

  Future<void> _setChannels(List<Channel> updated) async {
    final filtered = _applyFilter(
      query: _state.searchQuery,
      channels: updated,
      isReordering: _state.isReordering,
    );
    _setState(
      _state.copyWith(
        channels: updated,
        filteredChannels: filtered,
      ),
    );
    await _channelsService.saveChannelOrder(updated);
  }

  void _setState(HomeState state) {
    _state = state;
    notifyListeners();
  }

  List<Channel> _applyFilter({
    required String query,
    required List<Channel> channels,
    required bool isReordering,
  }) {
    if (isReordering || query.trim().isEmpty) {
      return List<Channel>.from(channels);
    }
    final lower = query.toLowerCase();
    return channels
        .where((channel) => channel.name.toLowerCase().contains(lower))
        .toList();
  }
}
