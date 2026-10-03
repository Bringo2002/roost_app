import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/auth_service.dart';

/// Kinds of listing interaction the backend accepts. [wireName] is the
/// exact enum name `POST /api/events/listings` expects.
enum ListingEventType {
  impression('IMPRESSION'),
  click('CLICK'),
  save('SAVE'),
  chatStarted('CHAT_STARTED'),
  application('APPLICATION');

  const ListingEventType(this.wireName);

  final String wireName;
}

typedef EventPoster = Future<dynamic> Function(
    String endpoint, Map<String, dynamic> body);
typedef SignedInCheck = Future<bool> Function();

class _QueuedEvent {
  const _QueuedEvent(this.propertyId, this.type);

  final int propertyId;
  final ListingEventType type;

  Map<String, dynamic> toJson() =>
      {'propertyId': propertyId, 'type': type.wireName};
}

Future<bool> _defaultSignedIn() async => (await AuthService.getToken()) != null;

/// Collects listing interactions and reports them to the backend in
/// batches, as the raw signal for listing ranking.
///
/// Telemetry must never get in the way of the app, so [track] is
/// synchronous and fire-and-forget, and a failed upload is logged and its
/// batch dropped rather than retried or surfaced to the user. Consequences
/// worth knowing: events still queued when the app is killed are lost
/// (the queue flushes after [flushDelay], or sooner once [maxBatchSize]
/// events are waiting), and a batch that fails to upload is not retried.
///
/// The backend only accepts events from signed-in users, so while signed
/// out the queue is discarded instead of sending requests that would
/// answer 401 and trigger a token refresh each time.
class ListingEventService {
  ListingEventService({
    EventPoster? poster,
    SignedInCheck? isSignedIn,
    this.flushDelay = const Duration(seconds: 10),
  })  : _post = poster ?? ApiService.post,
        _isSignedIn = isSignedIn ?? _defaultSignedIn;

  /// App-wide instance used by widgets and services.
  static final ListingEventService instance = ListingEventService();

  static const String endpoint = '/api/events/listings';

  /// Backend limit per request (`ListingEventBatchRequest.MAX_EVENTS`).
  static const int maxBatchSize = 50;

  /// Bound on queued events if uploads stall; the oldest are dropped first.
  static const int maxQueueLength = 200;

  final Duration flushDelay;
  final EventPoster _post;
  final SignedInCheck _isSignedIn;

  final ListQueue<_QueuedEvent> _queue = ListQueue<_QueuedEvent>();
  final Set<int> _impressed = <int>{};
  Timer? _timer;
  bool _flushing = false;

  /// Queues one interaction. Impressions are counted once per listing per
  /// app session; every other type is recorded each time it happens.
  void track(int propertyId, ListingEventType type) {
    if (type == ListingEventType.impression && !_impressed.add(propertyId)) {
      return;
    }
    if (_queue.length >= maxQueueLength) {
      _queue.removeFirst();
    }
    _queue.add(_QueuedEvent(propertyId, type));

    if (_queue.length >= maxBatchSize) {
      unawaited(flush());
    } else {
      _timer ??= Timer(flushDelay, () {
        _timer = null;
        unawaited(flush());
      });
    }
  }

  /// Sends everything queued, in batches of at most [maxBatchSize]. Safe to
  /// call at any time; a call while a flush is already running returns
  /// immediately and the running flush picks up the new events.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    if (_flushing || _queue.isEmpty) return;
    _flushing = true;
    try {
      if (!await _isSignedIn()) {
        _queue.clear();
        return;
      }
      while (_queue.isNotEmpty) {
        final batch = <_QueuedEvent>[];
        while (_queue.isNotEmpty && batch.length < maxBatchSize) {
          batch.add(_queue.removeFirst());
        }
        try {
          await _post(endpoint, {'events': batch.map((e) => e.toJson()).toList()});
        } on ApiException catch (e) {
          debugPrint('Listing events not sent (${batch.length} dropped): $e');
        }
      }
    } finally {
      _flushing = false;
    }
  }
}
