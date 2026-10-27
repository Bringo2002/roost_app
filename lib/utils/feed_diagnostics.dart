import 'package:flutter/foundation.dart';

/// The scenario that caused a feed refresh, for diagnostic bucketing.
enum FeedRefreshType {
  /// App cold start — first load with no cached data.
  coldStart,

  /// Widget rebuilt (e.g. tab switch) with data already available.
  warmStart,

  /// User moved to a new location that passed the movement threshold.
  locationChange,

  /// App resumed from background.
  appResume,

  /// User pulled to refresh or tapped retry.
  manualRefresh,

  /// Next-page fetch triggered by scroll.
  pagination,
}

/// Lightweight, privacy-conscious diagnostic instrumentation for the
/// location-aware property feed pipeline.
///
/// Usage:
/// ```dart
/// final trace = FeedDiagnostics.startRefresh(FeedRefreshType.locationChange, feedName: 'search');
/// trace.markLocationAcquired();
/// // ... fetch, filter, render ...
/// trace.finish();
/// ```
///
/// Logs a single structured line per refresh via [debugPrint] for easy
/// grep / DevTools filtering. Never logs precise user coordinates.
class FeedDiagnostics {
  FeedDiagnostics._();

  static int _nextId = 1;

  /// Begins a new traced refresh. Call the returned [RefreshTrace]'s mark
  /// methods as each pipeline stage completes, then [RefreshTrace.finish].
  static RefreshTrace startRefresh(
    FeedRefreshType type, {
    String? feedName,
  }) {
    return RefreshTrace._(
      refreshId: _nextId++,
      type: type,
      feedName: feedName,
    );
  }

  /// Resets the auto-incrementing ID counter. Only for test tearDown.
  @visibleForTesting
  static void resetIdCounter() => _nextId = 1;
}

/// A single feed-refresh trace. Created by [FeedDiagnostics.startRefresh].
///
/// Call the `mark*` methods as each pipeline stage completes. Each records
/// the monotonic elapsed time since the trace was started. Stages may be
/// skipped (e.g. a cache-hit refresh has no API call).
class RefreshTrace {
  RefreshTrace._({
    required this.refreshId,
    required this.type,
    this.feedName,
  }) : _stopwatch = Stopwatch()..start();

  /// Unique identifier for correlating log lines within a session.
  final int refreshId;

  /// What triggered this refresh.
  final FeedRefreshType type;

  /// Which feed surface ('home', 'search', etc.).
  final String? feedName;

  final Stopwatch _stopwatch;

  // Stage timestamps (elapsed ms from trace start, or null if skipped).
  int? _locationMs;
  int? _geocodeMs;
  int? _triggerMs;
  int? _apiSentMs;
  int? _apiReceivedMs;
  int? _filterSortMs;
  int? _statePublishedMs;
  int? _renderMs;

  int? _itemCount;
  int? _resultCount;
  bool _cacheHit = false;

  /// GPS fix obtained.
  void markLocationAcquired() => _locationMs = _stopwatch.elapsedMilliseconds;

  /// Reverse geocode finished.
  void markGeocodeComplete() => _geocodeMs = _stopwatch.elapsedMilliseconds;

  /// Feed refresh method entered (time from location to trigger).
  void markFeedTriggered() => _triggerMs = _stopwatch.elapsedMilliseconds;

  /// HTTP request dispatched.
  void markApiRequestSent() => _apiSentMs = _stopwatch.elapsedMilliseconds;

  /// HTTP response received and decoded.
  void markApiResponseReceived({
    required int itemCount,
    bool cacheHit = false,
  }) {
    _apiReceivedMs = _stopwatch.elapsedMilliseconds;
    _itemCount = itemCount;
    _cacheHit = cacheHit;
  }

  /// Client-side filtering and sorting complete.
  void markFilterSortComplete({required int resultCount}) {
    _filterSortMs = _stopwatch.elapsedMilliseconds;
    _resultCount = resultCount;
  }

  /// setState called — new state published to the widget tree.
  void markStatePublished() =>
      _statePublishedMs = _stopwatch.elapsedMilliseconds;

  /// First frame with new listing cards rendered.
  void markRenderComplete() => _renderMs = _stopwatch.elapsedMilliseconds;

  /// Stops the trace and logs the summary. Safe to call multiple times
  /// (subsequent calls are no-ops).
  void finish() {
    if (!_stopwatch.isRunning) return;
    _stopwatch.stop();
    final total = _stopwatch.elapsedMilliseconds;

    final parts = <String>[
      'refreshId=$refreshId',
      'type=${type.name}',
      if (feedName != null) 'feed=$feedName',
    ];

    void addStage(String name, int? ms) {
      if (ms != null) parts.add('$name=${ms}ms');
    }

    addStage('location', _locationMs);
    addStage('geocode', _geocodeMs);
    addStage('trigger', _triggerMs);
    addStage('apiSent', _apiSentMs);
    addStage('apiRecv', _apiReceivedMs);
    addStage('filter', _filterSortMs);
    addStage('state', _statePublishedMs);
    addStage('render', _renderMs);

    parts.add('total=${total}ms');
    if (_itemCount != null) parts.add('items=$_itemCount');
    if (_resultCount != null) parts.add('results=$_resultCount');
    parts.add('cache=${_cacheHit ? "hit" : "miss"}');

    debugPrint('[FeedDiag] ${parts.join(" ")}');
  }
}
