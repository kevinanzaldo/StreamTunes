import 'dart:async';
import 'dart:math';

import '../config/app_constants.dart';
import '../data/mock_data.dart';
import '../models/donation.dart';

/// Servicio de demostración local (legacy): emite donaciones simuladas en
/// memoria cada [interval]. El flujo real persiste vía `DonationRepository`.
class DonacionesService {
  static final DonacionesService _instance = DonacionesService._internal();
  factory DonacionesService() => _instance;
  DonacionesService._internal();

  final StreamController<Donation> _donacionesController =
      StreamController<Donation>.broadcast();

  Timer? _simulationTimer;

  Stream<Donation> get streamDonaciones => _donacionesController.stream;

  void emitirDonacion(Donation donacion) {
    if (!_donacionesController.isClosed) {
      _donacionesController.add(donacion);
    }
  }

  /// Inicia la simulación periódica emitiendo una donación cada [interval] (por defecto 10 segundos).
  void iniciarSimulacion({
    Duration interval = const Duration(seconds: 10),
    String? targetArtistId,
  }) {
    detenerSimulacion();

    final random = Random();
    final sampleMessages = [
      '¡Aguante la música independiente!',
      'Para que graben el próximo disco 🎸',
      'Gran recital el de anoche, sigan así!',
      'Un saludo desde Rosario 🤘',
      '¡Genios totales!',
      'Para las cuerdas de la viola',
    ];

    _simulationTimer = Timer.periodic(interval, (timer) {
      if (_donacionesController.isClosed) {
        timer.cancel();
        return;
      }

      final artist = (targetArtistId != null)
          ? MockData.getArtistById(targetArtistId) ?? MockData.artists.first
          : MockData.artists[random.nextInt(MockData.artists.length)];

      final amount =
          kDonationAmountsArs[random.nextInt(kDonationAmountsArs.length)];
      final message = sampleMessages[random.nextInt(sampleMessages.length)];

      final donation = Donation(
        id: 'don_${DateTime.now().millisecondsSinceEpoch}',
        artistId: artist.id,
        artistName: artist.name,
        amount: amount,
        currency: 'ARS',
        message: message,
        paymentMethod: 'MercadoPago',
        timestamp: DateTime.now(),
      );

      emitirDonacion(donation);
    });
  }

  void detenerSimulacion() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  void dispose() {
    detenerSimulacion();
    _donacionesController.close();
  }
}
