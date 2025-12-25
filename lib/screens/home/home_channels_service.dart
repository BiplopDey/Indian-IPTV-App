import '../../domain/entities/channel.dart';
import '../../provider/channels_provider.dart';

abstract class HomeChannelsService {
  Future<List<Channel>> fetchChannels();
  Future<List<Channel>> fetchRemoteChannels({bool forceRefresh = false});
  Future<void> saveChannelOrder(List<Channel> ordered);
  Future<void> removeCustomChannelByName(String name);
  String normalizeName(String value);
}

class ChannelsProviderService implements HomeChannelsService {
  ChannelsProviderService(this._provider);

  final ChannelsProvider _provider;

  @override
  Future<List<Channel>> fetchChannels() {
    return _provider.fetchM3UFile();
  }

  @override
  Future<List<Channel>> fetchRemoteChannels({bool forceRefresh = false}) {
    return _provider.fetchRemoteChannels(forceRefresh: forceRefresh);
  }

  @override
  Future<void> saveChannelOrder(List<Channel> ordered) {
    return _provider.saveChannelOrder(ordered);
  }

  @override
  Future<void> removeCustomChannelByName(String name) {
    return _provider.removeCustomChannelByName(name);
  }

  @override
  String normalizeName(String value) {
    return _provider.normalizeName(value);
  }
}
