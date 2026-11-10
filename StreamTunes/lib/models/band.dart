/// Estado de moderación de una banda (enum `band_status` en la base).
enum BandStatus {
  pending,
  approved,
  suspended;

  static BandStatus fromDb(String value) {
    return BandStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => BandStatus.pending,
    );
  }

  String get dbValue => name;
  String toDbString() => name;
}

/// Perfil público de una banda (tabla `bands`).
class Band {
  final String id;
  final String slug;
  final String name;
  final String bio;
  final String genre;
  final String location;
  final String? coverUrl;
  final Map<String, String> socialLinks;
  final double donationGoal;
  final double donationsCollected;
  final BandStatus status;
  final String createdBy;
  final DateTime createdAt;

  const Band({
    required this.id,
    required this.slug,
    required this.name,
    this.bio = '',
    this.genre = '',
    this.location = '',
    this.coverUrl,
    this.socialLinks = const {},
    this.donationGoal = 0,
    this.donationsCollected = 0,
    this.status = BandStatus.pending,
    required this.createdBy,
    required this.createdAt,
  });

  bool get isApproved => status == BandStatus.approved;

  /// Convierte un nombre en un `slug` válido para la base (`^[a-z0-9-]{2,60}$`):
  /// minúsculas, sin tildes y con guiones. Puede devolver menos de 2 caracteres
  /// si el nombre no tiene letras ni números; quien lo use debe validarlo.
  static String slugify(String name) {
    const accents = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'í': 'i',
      'ï': 'i',
      'ó': 'o',
      'ö': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    final plain = name
        .toLowerCase()
        .split('')
        .map((ch) => accents[ch] ?? ch)
        .join();
    final slug = plain
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.length <= 60 ? slug : slug.substring(0, 60);
  }

  double get donationProgress {
    if (donationGoal <= 0) return 1.0;
    return (donationsCollected / donationGoal).clamp(0.0, 1.0);
  }

  factory Band.fromJson(Map<String, dynamic> json) {
    final rawLinks = json['social_links'];
    final links = <String, String>{};
    if (rawLinks is Map) {
      rawLinks.forEach((key, value) {
        if (value != null) links[key.toString()] = value.toString();
      });
    }
    return Band(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      bio: (json['bio'] as String?) ?? '',
      genre: (json['genre'] as String?) ?? '',
      location: (json['location'] as String?) ?? '',
      coverUrl: json['cover_url'] as String?,
      socialLinks: links,
      donationGoal: (json['donation_goal'] as num?)?.toDouble() ?? 0,
      donationsCollected:
          (json['donations_collected'] as num?)?.toDouble() ?? 0,
      status: BandStatus.fromDb((json['status'] as String?) ?? 'pending'),
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Campos permitidos al crear una banda. `status`, `id` y los acumulados
  /// los define la base (privilegios por columna, ver 0003_hardening.sql).
  Map<String, dynamic> toInsertJson() => {
    'slug': slug,
    'name': name,
    'bio': bio,
    'genre': genre,
    'location': location,
    'cover_url': coverUrl,
    'social_links': socialLinks,
    'donation_goal': donationGoal,
    'created_by': createdBy,
  };

  /// Campos que el owner puede editar.
  Map<String, dynamic> toUpdateJson() => {
    'name': name,
    'bio': bio,
    'genre': genre,
    'location': location,
    'cover_url': coverUrl,
    'social_links': socialLinks,
    'donation_goal': donationGoal,
  };

  Band copyWith({
    String? id,
    String? slug,
    String? name,
    String? bio,
    String? genre,
    String? location,
    String? coverUrl,
    Map<String, String>? socialLinks,
    double? donationGoal,
    double? donationsCollected,
    BandStatus? status,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return Band(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      genre: genre ?? this.genre,
      location: location ?? this.location,
      coverUrl: coverUrl ?? this.coverUrl,
      socialLinks: socialLinks ?? this.socialLinks,
      donationGoal: donationGoal ?? this.donationGoal,
      donationsCollected: donationsCollected ?? this.donationsCollected,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Band && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
