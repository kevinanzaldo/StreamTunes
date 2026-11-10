import '../config/app_config.dart';
import '../services/supabase_service.dart';
import 'fake/fake_auth_repository.dart';
import 'fake/fake_band_repository.dart';
import 'fake/fake_donation_repository.dart';
import 'fake/fake_playlist_repository.dart';
import 'fake/fake_report_repository.dart';
import 'fake/fake_song_repository.dart';
import 'fake/fake_storage_repository.dart';
import 'interfaces/auth_repository.dart';
import 'interfaces/band_repository.dart';
import 'interfaces/donation_repository.dart';
import 'interfaces/playlist_repository.dart';
import 'interfaces/report_repository.dart';
import 'interfaces/song_repository.dart';
import 'interfaces/storage_repository.dart';
import 'supabase/supabase_auth_repository.dart';
import 'supabase/supabase_band_repository.dart';
import 'supabase/supabase_donation_repository.dart';
import 'supabase/supabase_playlist_repository.dart';
import 'supabase/supabase_report_repository.dart';
import 'supabase/supabase_song_repository.dart';
import 'supabase/supabase_storage_repository.dart';

/// Agrupa los repositorios de la app y elige la implementación según
/// `AppConfig.shouldUseMock` (o el parámetro `useMock`, útil en tests).
///
/// Si se crea con `useMock: false`, `SupabaseService.initialize()` ya debe
/// haberse ejecutado (lo hace `main.dart`).
class AppRepositories {
  AppRepositories({
    required this.auth,
    required this.songs,
    required this.bands,
    required this.playlists,
    required this.donations,
    StorageRepository? storage,
    ReportRepository? reports,
  }) : storage = storage ?? FakeStorageRepository(),
       reports = reports ?? FakeReportRepository();

  final AuthRepository auth;
  final SongRepository songs;
  final BandRepository bands;
  final PlaylistRepository playlists;
  final DonationRepository donations;
  final StorageRepository storage;
  final ReportRepository reports;

  factory AppRepositories.create({bool? useMock}) {
    if (useMock ?? AppConfig.shouldUseMock) {
      return AppRepositories(
        auth: FakeAuthRepository(),
        songs: FakeSongRepository(),
        bands: FakeBandRepository(),
        playlists: FakePlaylistRepository(),
        donations: FakeDonationRepository(),
        storage: FakeStorageRepository(),
        reports: FakeReportRepository(),
      );
    }
    final client = SupabaseService.client;
    return AppRepositories(
      auth: SupabaseAuthRepository(client),
      songs: SupabaseSongRepository(client),
      bands: SupabaseBandRepository(client),
      playlists: SupabasePlaylistRepository(client),
      donations: SupabaseDonationRepository(client),
      storage: SupabaseStorageRepository(client),
      reports: SupabaseReportRepository(client),
    );
  }
}
