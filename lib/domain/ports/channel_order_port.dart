abstract class ChannelOrderPort {
  Future<List<String>> loadOrder(String key);
  Future<void> saveOrder(String key, List<String> names);
}
