import 'package:flutter/foundation.dart';

class OyenteTop {
  final String nombre;
  final int minutos;
  final String ubicacion;
  final String? avatarUrl;
  final bool isPublic;

  const OyenteTop({
    required this.nombre,
    required this.minutos,
    this.ubicacion = '',
    this.avatarUrl,
    this.isPublic = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OyenteTop &&
          nombre == other.nombre &&
          minutos == other.minutos &&
          ubicacion == other.ubicacion &&
          avatarUrl == other.avatarUrl &&
          isPublic == other.isPublic;

  @override
  int get hashCode =>
      Object.hash(nombre, minutos, ubicacion, avatarUrl, isPublic);
}

class TemaMetrica {
  final String songId;
  final String titulo;
  final int reproducciones;
  final int minutos;

  const TemaMetrica({
    required this.songId,
    required this.titulo,
    required this.reproducciones,
    required this.minutos,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemaMetrica &&
          songId == other.songId &&
          titulo == other.titulo &&
          reproducciones == other.reproducciones &&
          minutos == other.minutos;

  @override
  int get hashCode => Object.hash(songId, titulo, reproducciones, minutos);
}

class DiaMetrica {
  final String fecha;
  final int reproducciones;
  final int minutos;

  const DiaMetrica({
    required this.fecha,
    required this.reproducciones,
    required this.minutos,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiaMetrica &&
          fecha == other.fecha &&
          reproducciones == other.reproducciones &&
          minutos == other.minutos;

  @override
  int get hashCode => Object.hash(fecha, reproducciones, minutos);
}

class MetricasArtista {
  final int totalMinutos;
  final int totalReproducciones;
  final List<OyenteTop> rankingOyentes;
  final List<TemaMetrica> topTemas;
  final List<DiaMetrica> reproduccionesPorDia;
  final int totalEventosReales;

  const MetricasArtista({
    required this.totalMinutos,
    required this.totalReproducciones,
    required this.rankingOyentes,
    this.topTemas = const [],
    this.reproduccionesPorDia = const [],
    this.totalEventosReales = 0,
  });

  /// Instancia vacía por defecto cuando no hay métricas registradas.
  static const MetricasArtista empty = MetricasArtista(
    totalMinutos: 0,
    totalReproducciones: 0,
    rankingOyentes: [],
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MetricasArtista &&
          totalMinutos == other.totalMinutos &&
          totalReproducciones == other.totalReproducciones &&
          listEquals(rankingOyentes, other.rankingOyentes) &&
          listEquals(topTemas, other.topTemas) &&
          listEquals(reproduccionesPorDia, other.reproduccionesPorDia) &&
          totalEventosReales == other.totalEventosReales;

  @override
  int get hashCode => Object.hash(
    totalMinutos,
    totalReproducciones,
    Object.hashAll(rankingOyentes),
    Object.hashAll(topTemas),
    Object.hashAll(reproduccionesPorDia),
    totalEventosReales,
  );
}
