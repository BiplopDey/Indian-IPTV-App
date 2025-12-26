class CastMediaItem {
  final Uri streamUrl;
  final String title;
  final String? subtitle;
  final Uri? imageUrl;
  final String contentType;
  final bool isLive;

  const CastMediaItem({
    required this.streamUrl,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.contentType = 'application/x-mpegURL',
    this.isLive = true,
  });
}
