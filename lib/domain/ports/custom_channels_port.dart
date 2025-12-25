import '../entities/channel.dart';

abstract class CustomChannelsPort {
  Future<List<Channel>> loadCustomChannels(
    String key, {
    required String defaultLogoUrl,
  });
  Future<void> saveCustomChannels(String key, List<Channel> channels);
}
