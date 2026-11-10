import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/artist.dart';
import '../models/donation.dart';
import '../models/metricas_artista.dart';
import '../models/song.dart';
import '../repositories/app_repositories.dart';
import '../repositories/interfaces/song_repository.dart';
import '../repositories/music_repository.dart';
import '../services/dispositivo_capacidades.dart';
import '../services/donaciones_service.dart';

class ArtistDetailViewModel extends ChangeNotifier {
  final Artist artist;
  // Solo para generar y procesar los 50.000 registros de la demo de Isolate.
  final MusicRepository _musicRepository;
  final SongRepository _songRepository;
  final DonacionesService _donacionesService;
  final DispositivoCapacidades _dispositivoCapacidades;

  StreamSubscription<Donation>? _donacionesSubscription;
  Donation? _ultimaDonacion;
  bool _mostrarAlertaDonacion = false;
  final List<Donation> _muroDonaciones = [];

  List<Song> _songs = const [];
  bool _cargandoTemas = false;
  String? _errorTemas;

  bool _calculandoEstadisticas = false;
  int? _totalMinutosEscuchados;
  MetricasArtista? _metricas;
  String? _errorEstadisticas;

  bool _tieneCamara = false;
  bool _disposed = false;
  final List<String> _historias = [
    'Ensayo general 🎸',
    'Setlist de la gira 📝',
  ];

  ArtistDetailViewModel({
    required this.artist,
    MusicRepository? musicRepository,
    SongRepository? songRepository,
    DonacionesService? donacionesService,
    DispositivoCapacidades? dispositivoCapacidades,
    bool autoEscucharDonaciones = true,
    bool autoIniciarSimulacion = false,
    bool autoCargarTemas = true,
  }) : _musicRepository = musicRepository ?? MusicRepository(),
       _songRepository = songRepository ?? AppRepositories.create().songs,
       _donacionesService = donacionesService ?? DonacionesService(),
       _dispositivoCapacidades =
           dispositivoCapacidades ?? DispositivoCapacidades() {
    _verificarCamara();
    if (autoEscucharDonaciones) {
      _iniciarEscuchaDonaciones();
    }
    if (autoIniciarSimulacion) {
      iniciarSimulacionDonaciones();
    }
    if (autoCargarTemas) {
      cargarTemas();
    }
  }

  Donation? get ultimaDonacion => _ultimaDonacion;
  bool get mostrarAlertaDonacion => _mostrarAlertaDonacion;
  List<Donation> get muroDonaciones => List.unmodifiable(_muroDonaciones);
  bool get calculandoEstadisticas => _calculandoEstadisticas;
  int? get totalMinutosEscuchados => _totalMinutosEscuchados;
  MetricasArtista? get metricas => _metricas;
  String? get errorEstadisticas => _errorEstadisticas;

  /// Temas de la banda, del más escuchado al menos escuchado.
  List<Song> get songs => List.unmodifiable(_songs);
  bool get cargandoTemas => _cargandoTemas;
  String? get errorTemas => _errorTemas;

  bool get tieneCamara => _tieneCamara;
  List<String> get historias => List.unmodifiable(_historias);

  double get donacionesRecolectadas => artist.donationsCollected;
  double get metaDonaciones => artist.donationGoal;
  double get progresoDonaciones => artist.donationProgress;

  Future<void> _verificarCamara() async {
    _tieneCamara = await _dispositivoCapacidades.tieneCamara;
    _notify();
  }

  /// Carga (o recarga) los temas de la banda desde el repositorio.
  Future<void> cargarTemas() async {
    _cargandoTemas = true;
    _errorTemas = null;
    _notify();

    try {
      final temas = await _songRepository.getSongsByBand(artist.id);
      _songs = List<Song>.of(temas)
        ..sort((a, b) => b.playCount.compareTo(a.playCount));
    } catch (e, st) {
      debugPrint('ArtistDetailViewModel: error cargando temas: $e\n$st');
      _errorTemas = 'No se pudieron cargar los temas.';
    } finally {
      _cargandoTemas = false;
      _notify();
    }
  }

  void _iniciarEscuchaDonaciones() {
    _donacionesSubscription = _donacionesService.streamDonaciones
        .where((d) => d.artistId == artist.id)
        .listen((donation) {
          _ultimaDonacion = donation;
          _muroDonaciones.insert(0, donation);
          artist.donationsCollected += donation.amount;
          _mostrarAlertaDonacion = true;
          _notify();
        });
  }

  void ocultarAlertaDonacion() {
    _mostrarAlertaDonacion = false;
    _notify();
  }

  /// Permite a cualquier fan enviar una donación en vivo a la banda.
  void donarSimulado({required double monto, required String mensaje}) {
    final donacion = Donation(
      id: 'don_${DateTime.now().millisecondsSinceEpoch}',
      artistId: artist.id,
      artistName: artist.name,
      amount: monto,
      currency: 'ARS',
      message: mensaje,
      paymentMethod: 'MercadoPago',
      timestamp: DateTime.now(),
    );
    _donacionesService.emitirDonacion(donacion);
  }

  /// Permite grabar historias cortas de 15 segundos con la cámara si está disponible.
  Future<void> grabarHistoria() async {
    final videoPath = await _dispositivoCapacidades.grabarHistoriaCorta();
    if (videoPath != null) {
      _historias.insert(
        0,
        'Historia nueva (${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')})',
      );
      _notify();
    }
  }

  /// Inicia la simulación de donaciones periódicas en tiempo real asociadas a este artista.
  void iniciarSimulacionDonaciones({
    Duration interval = const Duration(seconds: 10),
  }) {
    _donacionesService.iniciarSimulacion(
      interval: interval,
      targetArtistId: artist.id,
    );
  }

  /// Detiene la simulación activa de donaciones.
  void detenerSimulacionDonaciones() {
    _donacionesService.detenerSimulacion();
  }

  /// Procesa 50.000 registros en segundo plano delegando la plataforma al servicio de capacidades (Criterio D3).
  Future<void> calcularEstadisticasIsolate() async {
    _calculandoEstadisticas = true;
    _errorEstadisticas = null;
    _notify();

    try {
      final registros = _musicRepository.generatePlaybackRecords(
        artist.id,
        count: 50000,
      );

      // Desacoplamiento de plataforma: DispositivoCapacidades resuelve Isolate.run o compute (Regla 3)
      final metricasCalculadas = await _dispositivoCapacidades
          .ejecutarComputoPesado(
            MusicRepository.calculateAdvancedMetrics,
            registros,
          );

      _metricas = metricasCalculadas;
      _totalMinutosEscuchados = metricasCalculadas.totalMinutos;
    } catch (e) {
      _errorEstadisticas = 'Error calculando métricas: $e';
    } finally {
      _calculandoEstadisticas = false;
      _notify();
    }
  }

  /// Evita `notifyListeners` después de `dispose` cuando una carga termina tarde.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    detenerSimulacionDonaciones();
    _donacionesSubscription?.cancel();
    _donacionesSubscription = null;
    super.dispose();
  }
}
