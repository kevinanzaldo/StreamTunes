import 'dart:async';
import 'dart:isolate';

import 'package:flutter/material.dart';

import '../models/artist.dart';
import '../models/donation.dart';
import '../repositories/music_repository.dart';
import '../services/donaciones_service.dart';

class ArtistDetailViewModel extends ChangeNotifier {
  final Artist artist;
  final MusicRepository _musicRepository;
  final DonacionesService _donacionesService;

  StreamSubscription<Donation>? _donacionesSubscription;
  Donation? _ultimaDonacion;
  bool _mostrarAlertaDonacion = false;

  bool _calculandoEstadisticas = false;
  int? _totalMinutosEscuchados;
  String? _errorEstadisticas;

  ArtistDetailViewModel({
    required this.artist,
    MusicRepository? musicRepository,
    DonacionesService? donacionesService,
    bool autoEscucharDonaciones = true,
  }) : _musicRepository = musicRepository ?? MusicRepository(),
       _donacionesService = donacionesService ?? DonacionesService() {
    if (autoEscucharDonaciones) {
      _iniciarEscuchaDonaciones();
    }
  }

  Donation? get ultimaDonacion => _ultimaDonacion;
  bool get mostrarAlertaDonacion => _mostrarAlertaDonacion;
  bool get calculandoEstadisticas => _calculandoEstadisticas;
  int? get totalMinutosEscuchados => _totalMinutosEscuchados;
  String? get errorEstadisticas => _errorEstadisticas;

  double get donacionesRecolectadas => artist.donationsCollected;
  double get metaDonaciones => artist.donationGoal;
  double get progresoDonaciones => artist.donationProgress;

  void _iniciarEscuchaDonaciones() {
    _donacionesSubscription = _donacionesService.streamDonaciones
        .where((d) => d.artistId == artist.id)
        .listen((donation) {
          _ultimaDonacion = donation;
          artist.donationsCollected += donation.amount;
          _mostrarAlertaDonacion = true;
          notifyListeners();
        });
  }

  void ocultarAlertaDonacion() {
    _mostrarAlertaDonacion = false;
    notifyListeners();
  }

  /// Procesa 50.000 registros usando Isolate.run para evitar congelar el hilo principal y el reproductor de audio.
  Future<void> calcularEstadisticasIsolate() async {
    _calculandoEstadisticas = true;
    _errorEstadisticas = null;
    notifyListeners();

    try {
      final registros = _musicRepository.generatePlaybackRecords(
        artist.id,
        count: 50000,
      );

      // Ejecución paralela en segundo plano (Criterio D3)
      final minutosCalculados = await Isolate.run(
        () => MusicRepository.calculateTotalMinutes(registros),
      );

      _totalMinutosEscuchados = minutosCalculados;
    } catch (e) {
      _errorEstadisticas = 'Error calculando minutos: $e';
    } finally {
      _calculandoEstadisticas = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    // Obligatorio: cancelar suscripción para evitar memory leaks (Bloque 5)
    _donacionesSubscription?.cancel();
    _donacionesSubscription = null;
    super.dispose();
  }
}
