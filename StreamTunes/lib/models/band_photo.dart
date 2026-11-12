/// Foto de show o ensayo en la galería de una banda (tabla `band_photos`).
class BandPhoto {
  final String id;
  final String bandId;
  final String photoUrl;
  final String? caption;
  final DateTime createdAt;

  const BandPhoto({
    required this.id,
    required this.bandId,
    required this.photoUrl,
    this.caption,
    required this.createdAt,
  });

  factory BandPhoto.fromJson(Map<String, dynamic> json) {
    return BandPhoto(
      id: json['id'] as String,
      bandId: json['band_id'] as String,
      photoUrl: json['photo_url'] as String,
      caption: json['caption'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() => {
    'band_id': bandId,
    'photo_url': photoUrl,
    if (caption != null && caption!.trim().isNotEmpty)
      'caption': caption!.trim(),
  };
}
