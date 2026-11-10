import 'package:flutter/material.dart';

import '../models/artist.dart';
import '../models/playlist.dart';
import '../models/song.dart';

class MockData {
  /// Artista simulado que ha iniciado sesión (dueño de su perfil y de las subidas).
  static const String artistaLogueadoId = 'artist_1';

  // Artistas Independientes
  static final List<Artist> artists = [
    Artist(
      id: 'artist_1',
      name: 'Los Subterráneos',
      genre: 'Indie Rock',
      bio: 'Banda oriunda de Buenos Aires explorando texturas de guitarras analógicas, letras introspectivas y sonidos de garage.',
      monthlyListeners: 42300,
      avatarGradient: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
      avatarIcon: Icons.music_note,
      location: 'Buenos Aires, AR',
      donationGoal: 60000.0,
      donationsCollected: 34500.0,
    ),
    Artist(
      id: 'artist_2',
      name: 'Banda Fractal',
      genre: 'Synthwave / Indie Pop',
      bio: 'Dúo experimental que fusiona sintetizadores retro de los 80 con ritmos electrónicos futuristas y voces etéreas.',
      monthlyListeners: 28900,
      avatarGradient: const [Color(0xFFFF416C), Color(0xFFFF4B2B)],
      avatarIcon: Icons.album,
      location: 'Córdoba, AR',
      donationGoal: 45000.0,
      donationsCollected: 29000.0,
    ),
    Artist(
      id: 'artist_3',
      name: 'Terapia de Choque',
      genre: 'Post-Punk / Alternativo',
      bio: 'Sonido crudo, baterías potentes y líneas de bajo oscuras que capturan la energía urbana nocturna.',
      monthlyListeners: 15400,
      avatarGradient: const [Color(0xFF11998E), Color(0xFF38EF7D)],
      avatarIcon: Icons.headphones,
      location: 'Rosario, AR',
      donationGoal: 30000.0,
      donationsCollected: 18200.0,
    ),
    Artist(
      id: 'artist_4',
      name: 'Vientos Nómadas',
      genre: 'Folk Acústico / Andino',
      bio: 'Canciones acústicas de raíz folclórica con charango, quena y arreglos corales grabados en la cordillera.',
      monthlyListeners: 36700,
      avatarGradient: const [Color(0xFFF7971E), Color(0xFFFFD200)],
      avatarIcon: Icons.mic,
      location: 'Mendoza, AR',
      donationGoal: 50000.0,
      donationsCollected: 41000.0,
    ),
    Artist(
      id: 'artist_5',
      name: 'Cumbia Cósmica',
      genre: 'Cumbia Indie / Dub',
      bio: 'Pioneros en mezclar la cumbia villera tradicional con sintetizadores espaciales y cadencias psicodélicas.',
      monthlyListeners: 51200,
      avatarGradient: const [Color(0xFF00C9FF), Color(0xFF92FE9D)],
      avatarIcon: Icons.radio,
      location: 'La Plata, AR',
      donationGoal: 80000.0,
      donationsCollected: 52000.0,
    ),
  ];

  // Canciones con fecha de subida (algunas de esta semana, otras anteriores)
  static final List<Song> songs = [
    Song(
      id: 'song_1',
      title: 'El rito visual',
      artistId: 'artist_1',
      artistName: 'Los Subterráneos',
      album: 'Frecuencias Ocultas',
      duration: const Duration(minutes: 3, seconds: 42),
      genre: 'Indie Rock',
      icon: Icons.music_note,
      gradientColors: const [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=300',
      playCount: 14200,
      uploadedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Song(
      id: 'song_2',
      title: 'Cables Sueltos',
      artistId: 'artist_2',
      artistName: 'Banda Fractal',
      album: 'Circuito Primario',
      duration: const Duration(minutes: 4, seconds: 15),
      genre: 'Synthwave',
      icon: Icons.album,
      gradientColors: const [Color(0xFFFF416C), Color(0xFFFF4B2B)],
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=300',
      playCount: 9800,
      uploadedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Song(
      id: 'song_3',
      title: 'Ruido Blanco',
      artistId: 'artist_3',
      artistName: 'Terapia de Choque',
      album: 'Bajo Control',
      duration: const Duration(minutes: 2, seconds: 58),
      genre: 'Post-Punk',
      icon: Icons.headphones,
      gradientColors: const [Color(0xFF11998E), Color(0xFF38EF7D)],
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=300',
      playCount: 7400,
      uploadedAt: DateTime.now().subtract(const Duration(days: 14)),
    ),
    Song(
      id: 'song_4',
      title: 'Ecos del Sur',
      artistId: 'artist_4',
      artistName: 'Vientos Nómadas',
      album: 'Camino Abierto',
      duration: const Duration(minutes: 3, seconds: 20),
      genre: 'Folk Acústico',
      icon: Icons.mic,
      gradientColors: const [Color(0xFFF7971E), Color(0xFFFFD200)],
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1498038432885-c6f3f1b912ee?w=300',
      playCount: 18300,
      uploadedAt: DateTime.now().subtract(const Duration(days: 22)),
    ),
    Song(
      id: 'song_5',
      title: 'Galaxia Tropical',
      artistId: 'artist_5',
      artistName: 'Cumbia Cósmica',
      album: 'Viaje Estelar',
      duration: const Duration(minutes: 3, seconds: 50),
      genre: 'Cumbia Indie',
      icon: Icons.radio,
      gradientColors: const [Color(0xFF00C9FF), Color(0xFF92FE9D)],
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=300',
      playCount: 22100,
      uploadedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    Song(
      id: 'song_6',
      title: 'Niebla en la Ciudad',
      artistId: 'artist_1',
      artistName: 'Los Subterráneos',
      album: 'Frecuencias Ocultas',
      duration: const Duration(minutes: 4, seconds: 05),
      genre: 'Indie Rock',
      icon: Icons.nightlife,
      gradientColors: const [Color(0xFF3A1C71), Color(0xFFD76D77)],
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=300',
      playCount: 8900,
      uploadedAt: DateTime.now().subtract(const Duration(days: 18)),
    ),
    Song(
      id: 'song_7',
      title: 'Luces de Neón',
      artistId: 'artist_2',
      artistName: 'Banda Fractal',
      album: 'Circuito Primario',
      duration: const Duration(minutes: 3, seconds: 35),
      genre: 'Synthwave',
      icon: Icons.auto_awesome,
      gradientColors: const [Color(0xFF654ea3), Color(0xFFeaafc8)],
      audioUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3',
      coverUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=300',
      playCount: 12500,
      uploadedAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
    Song(
      id: 'song_8',
      title: 'Cielo Andino',
      artistId: 'artist_4',
      artistName: 'Vientos Nómadas',
      album: 'Camino Abierto',
      duration: const Duration(minutes: 4, seconds: 30),
      genre: 'Folk Acústico',
      icon: Icons.landscape,
      gradientColors: const [Color(0xFF56ab2f), Color(0xFFA8E063)],
      playCount: 14700,
      uploadedAt: DateTime.now().subtract(const Duration(days: 35)),
    ),
  ];

  // Playlists por defecto
  static List<Playlist> getInitialPlaylists() {
    return [
      Playlist(
        id: 'pl_1',
        name: 'Joyas Ocultas del Indie',
        description: 'Descubrimientos semanales de proyectos independientes que merecen ser escuchados.',
        songs: [songs[0], songs[1], songs[3], songs[5]],
        coverGradient: const [Color(0xFF1DB954), Color(0xFF191414)],
        icon: Icons.auto_awesome,
      ),
      Playlist(
        id: 'pl_2',
        name: 'Vibra Nocturna',
        description: 'Synthwave, beats electrónicos y rock atmosférico para después de medianoche.',
        songs: [songs[1], songs[2], songs[6]],
        coverGradient: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
        icon: Icons.bedtime,
      ),
      Playlist(
        id: 'pl_3',
        name: 'Acústicos de la Tierra',
        description:
            'Canciones puras de madera, cuerdas y viento para conectar.',
        songs: [songs[3], songs[7]],
        coverGradient: const [Color(0xFFF7971E), Color(0xFFFFD200)],
        icon: Icons.park,
      ),
    ];
  }

  // Lista de géneros disponibles para filtros
  static const List<String> genres = [
    'Todos',
    'Indie Rock',
    'Synthwave',
    'Post-Punk',
    'Folk Acústico',
    'Cumbia Indie',
  ];

  static Artist? getArtistById(String id) {
    try {
      return artists.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<Song> getSongsByArtist(String artistId) {
    return songs.where((s) => s.artistId == artistId).toList();
  }
}
