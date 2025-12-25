class ChannelNormalizer {
  String normalizeName(String value) {
    final lower = value.toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    return cleaned.replaceAll(RegExp(r'\s+'), ' ');
  }
}
