/// La persona que inicia sesión (tabla `profiles`, 1:1 con `auth.users`).
/// No es el perfil público de una banda: para eso ver `Band`.
class Profile {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Solo los campos que la app puede editar (ver privilegios por columna).
  Map<String, dynamic> toUpdateJson() => {
    'display_name': displayName,
    'avatar_url': avatarUrl,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Profile && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
