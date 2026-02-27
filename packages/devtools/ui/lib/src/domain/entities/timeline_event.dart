/// Lightweight view entity for one timeline row.
class TimelineEventView {
  /// Creates a timeline event view model.
  const TimelineEventView({
    required this.title,
    required this.key,
    required this.timestamp,
  });

  /// Event title.
  final String title;

  /// Related key.
  final String key;

  /// Display timestamp.
  final String timestamp;
}
