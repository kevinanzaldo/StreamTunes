import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../models/artist.dart';
import '../models/donation.dart';
import '../models/metricas_artista.dart';
import '../repositories/music_repository.dart';
import '../services/dispositivo_capacidades.dart';
import '../services/donaciones_service.dart';

class ArtistDetailViewModel extends ChangeNotifier {
  final Artist artist;
  final MusicRepository _musicRepository;
  final DonacionesService _donacionesService;
  final DispositivoCapacidades _dispositivoCapacidades;

  StreamSubscription<Donation>? _donacionesSubscription;
  Donation? _ultimaDonacion;
  bool _mostrarAlertaDonacion = false;
  final List<Donation> _muroDonaciones = [];

  bool _calculandoEstadisticas = false;
  int? _totalMinutosEscuchados;
  MetricasArtista? _metricas;
  String? _errorEstadisticas;

  bool _tieneCamara = false;
  final List<String> _historias = [
    'Ensayo general 🎸',
    'Setlist de la gira 📝',
  ];

  ArtistDetailViewModel({
    required this.artist,
    MusicRepository? musicRepository,
    DonacionesService? donacionesService,
    DispositivoCapacidades? dispositivoCapacidades,
    bool autoEscucharDonaciones = true,
  }) : _musicRepository = musicRepository ?? MusicRepository(),
       _donacionesService = donacionesService ?? DonacionesService(),
       _dispositivoCapacidades =
           dispositivoCapacidades ?? DispositivoCapacidades() {
    _verificarCamara();
    if (autoEscucharDonaciones) {
      _iniciarEscuchaDonaciones();
    }
  }

  Donation? get ultimaDonacion => _ultimaDonacion;
  bool get mostrarAlertaDonacion => _mostrarAlertaDonacion;
  List<Donation> get muroDonaciones => List.unmodifiable(_muroDonaciones);
  bool get calculandoEstadisticas => _calculandoEstadisticas;
  int? get totalMinutosEscuchados => _totalMinutosEscuchados;
  MetricasArtista? get metricas => _metricas;
  String? get errorEstadisticas => _errorEstadisticas;

  bool get tieneCamara => _tieneCamara;
  List<String> get historias => List.unmodifiable(_historias);

  double get donacionesRecolectadas => artist.donationsCollected;
  double get metaDonaciones => artist.donationGoal;
  double get progresoDonaciones => artist.donationProgress;

  Future<void> _verificarCamara() async {
    _tieneCamara = await _dispositivoCapacidades.tieneCamara;
    notifyListeners();
  }

  void _iniciarEscuchaDonaciones() {
    _donacionesSubscription = _donacionesService.streamDonaciones
        .where((d) => d.artistId == artist.id)
        .listen((donation) {
          _ultimaDonacion = donation;
          _muroDonaciones.insert(0, donation);
          artist.donationsCollected += donation.amount;
          _mostrarAlertaDonacion = true;
          notifyListeners();
        });
  }

  void ocultarAlertaDonacion() {
    _mostrarAlertaDonacion = false;
    notifyListeners();
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
      notifyListeners();
    }
  }

  /// Procesa 50.000 registros usando Isolate.run para calcular minutos y top oyentes.
  Future<void> calcularEstadisticasIsolate() async {
    _calculandoEstadisticas = true;
    _errorEstadisticas = null;
    notifyListeners();

    try {
      final registros = _musicRepository.generatePlaybackRecords(
        artist.id,
        count: 50000,
      );

      // En Web (PWA / dart4web), Isolate.run arroja UnsupportedOperation; usamos compute().
      // En plataformas nativas (Android/iOS/Desktop) Isolate.run ejecuta en hilo secundario aislado (Criterio D3).
      final metricasCalculadas = kIsWeb
          ? await compute(MusicRepository.calculateAdvancedMetrics, registros)
          : await Isolate.run(
              () => MusicRepository.calculateAdvancedMetrics(registros),
            );

      _metricas = metricasCalculadas;
      _totalMinutosEscuchados = metricasCalculadas.totalMinutos;
    } catch (e) {
      _errorEstadisticas = 'Error calculando métricas: $e';
    } finally {
      _calculandoEstadisticas = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _donacionesSubscription?.cancel();
    _donacionesSubscription = null;
    super.dispose();
  }
}
