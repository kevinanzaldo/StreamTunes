/// Álbum de una banda (tabla `albums`).
class Album {
  final String id;
  final String bandId;
  final String title;
  final String? coverUrl;
  final DateTime createdAt;

  const Album({
    required this.id,
    required this.bandId,
    required this.title,
    this.coverUrl,
    required this.createdAt,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'] as String,
      bandId: json['band_id'] as String,
      title: json['title'] as String,
      coverUrl: json['cover_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() => {
    'band_id': bandId,
    'title': title,
    'cover_url': coverUrl,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Album && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
