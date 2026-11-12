enum ReportStatus {
  open,
  resolved,
  dismissed;

  static ReportStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'resolved':
        return ReportStatus.resolved;
      case 'dismissed':
        return ReportStatus.dismissed;
      case 'open':
      default:
        return ReportStatus.open;
    }
  }

  String toDbString() {
    switch (this) {
      case ReportStatus.resolved:
        return 'resolved';
      case ReportStatus.dismissed:
        return 'dismissed';
      case ReportStatus.open:
        return 'open';
    }
  }
}

class Report {
  final String id;
  final String reporterId;
  final String? bandId;
  final String? songId;
  final String reason;
  final ReportStatus status;
  final DateTime createdAt;
  final String? bandName;
  final String? songTitle;

  Report({
    required this.id,
    required this.reporterId,
    this.bandId,
    this.songId,
    required this.reason,
    this.status = ReportStatus.open,
    DateTime? createdAt,
    this.bandName,
    this.songTitle,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'] as String,
      reporterId: json['reporter_id'] as String,
      bandId: json['band_id'] as String?,
      songId: json['song_id'] as String?,
      reason: json['reason'] as String,
      status: ReportStatus.fromString((json['status'] as String?) ?? 'open'),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      bandName: json['bands']?['name'] as String?,
      songTitle: json['songs']?['title'] as String?,
    );
  }
}
