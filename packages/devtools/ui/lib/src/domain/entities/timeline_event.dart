/// Presentation model for a single row in the Events Timeline tab.
///
/// [TimelineEventView] is a **read-only view entity** derived from a raw
/// [QoraEvent] (protocol layer).  It contains only the information needed
/// to render one timeline row — human-readable strings pre-formatted for
/// display — so the UI layer has zero formatting logic.
///
/// ## Mapping from protocol events
///
/// | [QoraEvent] subtype     | [title] format example                   |
/// |-------------------------|------------------------------------------|
/// | [QueryEvent]            | `'query · success'`, `'query · loading'` |
/// | [MutationEvent]         | `'mutation · started'`                   |
/// | [GenericQoraEvent]      | event `kind` string                      |
///
/// ## Scaling note
///
/// [TimelineController] stores [TimelineEventView]s in a capped ring buffer
/// (default 500 entries).  This entity is intentionally kept lightweight
/// (three `String` fields) to minimise memory impact at high event rates.
class TimelineEventView {
  /// Creates a timeline event view model from pre-formatted display strings.
  const TimelineEventView({
    required this.title,
    required this.key,
    required this.timestamp,
  });

  /// Human-readable event label shown in the timeline row.
  ///
  /// Typically `'<domain> · <status>'`, e.g. `'query · success'`.
  final String title;

  /// String-serialised `QoraKey` associated with this event.
  ///
  /// Matches [QueryEvent.queryKey] or [MutationEvent.id] depending on the
  /// event domain.  Displayed in a secondary column for quick identification.
  final String key;

  /// Pre-formatted wall-clock timestamp string (e.g. `'14:32:07.123'`).
  ///
  /// Formatted at event ingestion time; stored as a `String` to avoid
  /// repeated `DateFormat` calls during list rendering.
  final String timestamp;
}
