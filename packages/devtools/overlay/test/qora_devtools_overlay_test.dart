import 'package:flutter_test/flutter_test.dart';
import 'package:qora_devtools_overlay/qora_devtools_overlay.dart';

void main() {
  group('OverlayTracker', () {
    test('records query events in ring buffer', () {
      final tracker = OverlayTracker();

      tracker.onQueryFetched('users', null, 'success');
      tracker.onQueryFetched('posts', null, 'success');

      expect(tracker.queryHistory.length, 2);
      expect(tracker.queryHistory.first.key, 'users');
    });

    test('records timeline events for each tracker call', () {
      final tracker = OverlayTracker();

      tracker.onQueryFetched('todos', null, 'success');
      tracker.onOptimisticUpdate('todos', {'title': 'new'});

      expect(tracker.timelineHistory.length, 2);
    });

    test('tracks mutation key through started → settled', () {
      final tracker = OverlayTracker();

      tracker.onMutationStarted('m1', 'users', {'name': 'Alice'});
      tracker.onMutationSettled('m1', true, {'id': 1});

      final events = tracker.mutationHistory;
      expect(events.length, 2);
      expect(events.last.success, true);
    });

    test('evicts oldest events when ring buffer is full', () {
      final tracker = OverlayTracker();

      for (var i = 0; i < 201; i++) {
        tracker.onQueryFetched('key_$i', null, 'success');
      }

      // Ring buffer capped at 200
      expect(tracker.queryHistory.length, 200);
      // Oldest entry evicted — first key should be key_1
      expect(tracker.queryHistory.first.key, 'key_1');
    });

    test('dispose closes streams and clears buffers', () {
      final tracker = OverlayTracker();
      tracker.onQueryFetched('k', null, 'success');

      tracker.dispose();

      expect(tracker.queryHistory, isEmpty);
      expect(tracker.timelineHistory, isEmpty);
    });

    test('calls after dispose are silently ignored', () {
      final tracker = OverlayTracker();
      tracker.dispose();

      // Should not throw
      expect(
          () => tracker.onQueryFetched('k', null, 'success'), returnsNormally);
      expect(() => tracker.onCacheCleared(), returnsNormally);
    });
  });
}
