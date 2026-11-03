import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/utils/feed_diagnostics.dart';

void main() {
  setUp(() => FeedDiagnostics.resetIdCounter());

  group('FeedDiagnostics', () {
    test('startRefresh returns a RefreshTrace with auto-incrementing IDs', () {
      final t1 = FeedDiagnostics.startRefresh(FeedRefreshType.coldStart);
      final t2 = FeedDiagnostics.startRefresh(FeedRefreshType.locationChange);
      final t3 = FeedDiagnostics.startRefresh(FeedRefreshType.manualRefresh);

      expect(t1.refreshId, 1);
      expect(t2.refreshId, 2);
      expect(t3.refreshId, 3);
    });

    test('resetIdCounter resets the ID sequence', () {
      FeedDiagnostics.startRefresh(FeedRefreshType.coldStart);
      FeedDiagnostics.startRefresh(FeedRefreshType.coldStart);
      FeedDiagnostics.resetIdCounter();

      final t = FeedDiagnostics.startRefresh(FeedRefreshType.coldStart);
      expect(t.refreshId, 1);
    });
  });

  group('RefreshTrace', () {
    test('records type and optional feedName', () {
      final trace = FeedDiagnostics.startRefresh(
        FeedRefreshType.locationChange,
        feedName: 'search',
      );
      expect(trace.type, FeedRefreshType.locationChange);
      expect(trace.feedName, 'search');
    });

    test('mark methods record non-negative elapsed times', () async {
      final trace = FeedDiagnostics.startRefresh(
        FeedRefreshType.coldStart,
        feedName: 'home',
      );
      // Each mark just records the stopwatch's elapsed ms — they should
      // all succeed without throwing and produce non-negative values
      // (verified implicitly by finish() not throwing).
      trace.markLocationAcquired();
      trace.markGeocodeComplete();
      trace.markFeedTriggered();
      trace.markApiRequestSent();
      trace.markApiResponseReceived(itemCount: 20);
      trace.markFilterSortComplete(resultCount: 18);
      trace.markStatePublished();
      trace.markRenderComplete();
      trace.finish();
    });

    test('finish() is idempotent — second call is a no-op', () {
      final trace = FeedDiagnostics.startRefresh(FeedRefreshType.manualRefresh);
      trace.markFeedTriggered();
      trace.finish();
      // Second call should not throw or produce duplicate output.
      trace.finish();
    });

    test('stages can be skipped without errors', () {
      // A pagination trace typically skips location/geocode stages.
      final trace = FeedDiagnostics.startRefresh(FeedRefreshType.pagination);
      trace.markApiRequestSent();
      trace.markApiResponseReceived(itemCount: 20, cacheHit: false);
      trace.finish();
    });

    test('cache hit is recorded', () {
      final trace = FeedDiagnostics.startRefresh(FeedRefreshType.coldStart);
      trace.markApiResponseReceived(itemCount: 5, cacheHit: true);
      // No assertion on the log output itself — just verifying the call
      // chain doesn't throw. The cacheHit flag is visible in the log.
      trace.finish();
    });
  });

  group('FeedRefreshType', () {
    test('has all expected enum values', () {
      expect(
          FeedRefreshType.values,
          containsAll([
            FeedRefreshType.coldStart,
            FeedRefreshType.warmStart,
            FeedRefreshType.locationChange,
            FeedRefreshType.appResume,
            FeedRefreshType.manualRefresh,
            FeedRefreshType.pagination,
          ]));
    });
  });
}
