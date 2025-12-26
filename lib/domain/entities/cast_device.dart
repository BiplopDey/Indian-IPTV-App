class CastDevice {
  final String id;
  final String name;
  final String? modelName;

  const CastDevice({
    required this.id,
    required this.name,
    this.modelName,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CastDevice && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
