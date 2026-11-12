/// La persona que inicia sesión (tabla `profiles`, 1:1 con `auth.users`).
/// No es el perfil público de una banda: para eso ver `Band`.
class Profile {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final bool isPublicProfile;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.isPublicProfile = false,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      displayName: (json['display_name'] as String?) ?? 'Fan anónimo',
      avatarUrl: json['avatar_url'] as String?,
      isPublicProfile: (json['is_public_profile'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Solo los campos que la app puede editar (ver privilegios por columna).
  Map<String, dynamic> toUpdateJson() => {
    'display_name': displayName,
    'avatar_url': avatarUrl,
    'is_public_profile': isPublicProfile,
  };

  Profile copyWith({
    String? displayName,
    String? avatarUrl,
    bool? isPublicProfile,
  }) {
    return Profile(
      id: id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isPublicProfile: isPublicProfile ?? this.isPublicProfile,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Profile && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
