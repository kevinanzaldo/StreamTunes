/// Constantes compartidas de reglas de negocio y catálogo de la app.
///
/// Las reglas críticas de cupo y montos máximos se validan también en Supabase
/// (triggers `songs_limit`, `albums_limit` y `donations_validate`, con valores
/// configurados en la tabla `app_config`).
const int kMaxSongsPerBand = 20;
const int kMaxAlbumsPerBand = 2;
const int kMinSongDurationSeconds = 60;

/// Tope y opciones predefinidas de donación en pesos argentinos ($ ARS).
const double kMaxDonationArs = 5000.0;
const List<double> kDonationAmountsArs = [500.0, 1000.0, 2000.0, 5000.0];

/// Formatea un monto entero en pesos argentinos con separador de miles (ej: `$5.000`).
String formatArsAmount(double amount) {
  final rounded = amount.round();
  final raw = rounded.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final posFromRight = raw.length - i;
    if (i > 0 && posFromRight % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(raw[i]);
  }
  return '\$$buffer';
}

/// Géneros musicales disponibles al publicar un tema nuevo.
const List<String> kSongGenres = [
  'Rock',
  'Indie',
  'Pop',
  'Folk',
  'Hip-Hop',
  'Electrónica',
  'Jazz',
  'Otro',
];
