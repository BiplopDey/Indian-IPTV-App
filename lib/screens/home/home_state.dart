import '../../domain/entities/channel.dart';

class HomeState {
  static const Object _sentinel = Object();

  final List<Channel> channels;
  final List<Channel> filteredChannels;
  final bool isLoading;
  final bool isReordering;
  final bool isLaunchingPlayer;
  final String? appVersion;
  final String searchQuery;
  final int? pendingLaunchIndex;

  const HomeState({
    required this.channels,
    required this.filteredChannels,
    required this.isLoading,
    required this.isReordering,
    required this.isLaunchingPlayer,
    required this.appVersion,
    required this.searchQuery,
    required this.pendingLaunchIndex,
  });

  const HomeState.initial()
      : channels = const [],
        filteredChannels = const [],
        isLoading = true,
        isReordering = false,
        isLaunchingPlayer = false,
        appVersion = null,
        searchQuery = '',
        pendingLaunchIndex = null;

  HomeState copyWith({
    List<Channel>? channels,
    List<Channel>? filteredChannels,
    bool? isLoading,
    bool? isReordering,
    bool? isLaunchingPlayer,
    Object? appVersion = _sentinel,
    String? searchQuery,
    Object? pendingLaunchIndex = _sentinel,
  }) {
    return HomeState(
      channels: channels ?? this.channels,
      filteredChannels: filteredChannels ?? this.filteredChannels,
      isLoading: isLoading ?? this.isLoading,
      isReordering: isReordering ?? this.isReordering,
      isLaunchingPlayer: isLaunchingPlayer ?? this.isLaunchingPlayer,
      appVersion:
          appVersion == _sentinel ? this.appVersion : appVersion as String?,
      searchQuery: searchQuery ?? this.searchQuery,
      pendingLaunchIndex: pendingLaunchIndex == _sentinel
          ? this.pendingLaunchIndex
          : pendingLaunchIndex as int?,
    );
  }
}
