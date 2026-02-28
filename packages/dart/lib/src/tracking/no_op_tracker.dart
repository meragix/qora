import 'qora_tracker.dart';

/// Production-safe [QoraTracker] implementation with zero runtime overhead.
///
/// [NoOpTracker] is the **default tracker** used by [QoraClient] when no
/// explicit tracker is injected.  Every method body is intentionally empty:
/// no allocations, no I/O, no observable side effects.
///
/// ## Why a class instead of null?
///
/// Rather than guarding every tracker call with a null check:
///
/// ```dart
/// // Avoided — scattered null checks, easy to forget one
/// _tracker?.onQueryFetched(key, data, status);
/// ```
///
/// [QoraClient] stores a non-null `QoraTracker` and delegates
/// unconditionally.  [NoOpTracker] satisfies the contract at zero cost while
/// keeping the call sites clean.
///
/// ## Usage
///
/// ```dart
/// // Explicit (rarely needed):
/// final client = QoraClient(tracker: const NoOpTracker());
///
/// // Implicit — QoraClient uses this when tracker is omitted:
/// final client = QoraClient();
/// ```
///
/// ## Swapping in debug builds
///
/// To enable DevTools observability in debug or profile builds, replace the
/// default with `VmTracker` (from `qora_devtools_extension`):
///
/// ```dart
/// // e.g. in debug/main.dart
/// final client = QoraClient(tracker: VmTracker());
/// ```
final class NoOpTracker implements QoraTracker {
  /// Creates a no-op tracker.
  ///
  /// Prefer `const NoOpTracker()` — a single instance can be reused across
  /// multiple [QoraClient] instances without any shared mutable state.
  const NoOpTracker();

  @override
  void onQueryFetched(String key, Object? data, dynamic status) {}

  @override
  void onQueryInvalidated(String key) {}

  @override
  void onMutationStarted(String id, String key, Object? variables) {}

  @override
  void onMutationSettled(String id, bool success, Object? result) {}

  @override
  void onOptimisticUpdate(String key, Object? optimisticData) {}

  @override
  void onCacheCleared() {}

  @override
  void dispose() {}
}
