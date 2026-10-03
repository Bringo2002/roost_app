import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:roost_app/services/listing_event_service.dart';

/// Reports that a listing was shown, once the widget has stayed on screen
/// for [dwell] (default 1 second) -- so a card flicked past during a fast
/// scroll is not counted, and an unmounted card never reports at all.
///
/// "On screen" here means *built and mounted*, which is an approximation:
/// a lazy list builds a card slightly before it scrolls into view (its
/// cache extent), so a listing just outside the viewport that stays built
/// for [dwell] can be counted. That slight over-count is accepted for now
/// to avoid adding a visibility-detection dependency; if it proves to
/// matter, replace the timer start with a real visibility signal here and
/// no call site changes.
///
/// A null [propertyId] (an unsaved draft or preview) is never reported.
class ImpressionTracker extends StatefulWidget {
  const ImpressionTracker({
    super.key,
    required this.propertyId,
    required this.child,
    this.dwell = const Duration(seconds: 1),
    this.onImpression,
  });

  final int? propertyId;
  final Widget child;
  final Duration dwell;

  /// Replaces the default report to [ListingEventService.instance]; used
  /// by tests so they need no network or singleton.
  final void Function(int propertyId)? onImpression;

  @override
  State<ImpressionTracker> createState() => _ImpressionTrackerState();
}

class _ImpressionTrackerState extends State<ImpressionTracker> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(ImpressionTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A recycled element now showing a different listing starts a fresh
    // dwell; it must not inherit time spent on the previous one.
    if (oldWidget.propertyId != widget.propertyId) {
      _timer?.cancel();
      _start();
    }
  }

  void _start() {
    final id = widget.propertyId;
    if (id == null) return;
    _timer = Timer(widget.dwell, () {
      final report = widget.onImpression ??
          (int id) => ListingEventService.instance
              .track(id, ListingEventType.impression);
      report(id);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
