class OyenteTop {
  final String nombre;
  final int minutos;
  final String ubicacion;

  const OyenteTop({
    required this.nombre,
    required this.minutos,
    required this.ubicacion,
  });
}

class MetricasArtista {
  final int totalMinutos;
  final int totalReproducciones;
  final List<OyenteTop> rankingOyentes;

  const MetricasArtista({
    required this.totalMinutos,
    required this.totalReproducciones,
    required this.rankingOyentes,
  });
}

