/// Fecha de recital o show en la agenda de una banda (tabla `band_events`).
class BandEvent {
  final String id;
  final String bandId;
  final String title;
  final String venue;
  final String city;
  final DateTime eventDate;
  final String? ticketUrl;
  final String? notes;

  const BandEvent({
    required this.id,
    required this.bandId,
    required this.title,
    required this.venue,
    this.city = '',
    required this.eventDate,
    this.ticketUrl,
    this.notes,
  });

  factory BandEvent.fromJson(Map<String, dynamic> json) {
    return BandEvent(
      id: json['id'] as String,
      bandId: json['band_id'] as String,
      title: json['title'] as String,
      venue: json['venue'] as String,
      city: (json['city'] as String?) ?? '',
      eventDate: DateTime.parse(json['event_date'] as String),
      ticketUrl: json['ticket_url'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toInsertJson() => {
    'band_id': bandId,
    'title': title.trim(),
    'venue': venue.trim(),
    'city': city.trim(),
    'event_date': eventDate.toUtc().toIso8601String(),
    if (ticketUrl != null && ticketUrl!.trim().isNotEmpty)
      'ticket_url': ticketUrl!.trim(),
    if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
  };

  String get formattedDate {
    final day = eventDate.day.toString().padLeft(2, '0');
    final month = eventDate.month.toString().padLeft(2, '0');
    final hour = eventDate.hour.toString().padLeft(2, '0');
    final minute = eventDate.minute.toString().padLeft(2, '0');
    return '$day/$month/${eventDate.year} · $hour:$minute hs';
  }
}
