import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/services/api_service.dart';
import 'package:roost_app/services/listing_event_service.dart';

void main() {
  late List<Map<String, dynamic>> bodies;
  late bool signedIn;
  late Object? failWith;

  ListingEventService build({Duration flushDelay = const Duration(seconds: 10)}) {
    return ListingEventService(
      flushDelay: flushDelay,
      isSignedIn: () async => signedIn,
      poster: (endpoint, body) async {
        expect(endpoint, '/api/events/listings');
        if (failWith != null) throw failWith!;
        bodies.add(body);
        return {'accepted': 0, 'dropped': 0};
      },
    );
  }

  List<Map<String, dynamic>> eventsOf(Map<String, dynamic> body) =>
      (body['events'] as List).cast<Map<String, dynamic>>();

  setUp(() {
    bodies = [];
    signedIn = true;
    failWith = null;
  });

  group('track + flush', () {
    test('sends queued events with the backend wire names', () async {
      final service = build();

      service.track(1, ListingEventType.impression);
      service.track(2, ListingEventType.chatStarted);
      await service.flush();

      expect(bodies, hasLength(1));
      expect(eventsOf(bodies.single), [
        {'propertyId': 1, 'type': 'IMPRESSION'},
        {'propertyId': 2, 'type': 'CHAT_STARTED'},
      ]);
    });

    test('counts an impression once per listing per session', () async {
      final service = build();

      service.track(1, ListingEventType.impression);
      service.track(1, ListingEventType.impression);
      service.track(2, ListingEventType.impression);
      await service.flush();

      expect(eventsOf(bodies.single).map((e) => e['propertyId']), [1, 2]);
    });

    test('does not de-duplicate clicks', () async {
      final service = build();

      service.track(1, ListingEventType.click);
      service.track(1, ListingEventType.click);
      await service.flush();

      expect(eventsOf(bodies.single), hasLength(2));
    });

    test('an impression is still counted after the same listing was clicked', () async {
      final service = build();

      service.track(1, ListingEventType.click);
      service.track(1, ListingEventType.impression);
      await service.flush();

      expect(eventsOf(bodies.single).map((e) => e['type']), ['CLICK', 'IMPRESSION']);
    });

    test('flush with nothing queued sends nothing', () async {
      final service = build();

      await service.flush();

      expect(bodies, isEmpty);
    });
  });

  group('batching', () {
    test('never sends more than the backend limit per request', () async {
      final service = build();

      for (var i = 0; i < 120; i++) {
        service.track(i, ListingEventType.click);
      }
      // Reaching the batch size starts a flush on its own; wait for it.
      await pumpEventQueue();

      expect(bodies.map((b) => eventsOf(b).length), [50, 50, 20]);
      expect(ListingEventService.maxBatchSize, 50);
    });
  });

  group('failure handling', () {
    test('a failed upload drops that batch without throwing, and later events still send', () async {
      final service = build();

      failWith = ApiException('No internet connection');
      service.track(1, ListingEventType.click);
      await service.flush();
      expect(bodies, isEmpty);

      failWith = null;
      service.track(2, ListingEventType.click);
      await service.flush();
      expect(eventsOf(bodies.single), [
        {'propertyId': 2, 'type': 'CLICK'},
      ]);
    });

    test('while signed out nothing is sent and the queue is discarded', () async {
      final service = build();

      signedIn = false;
      service.track(1, ListingEventType.click);
      await service.flush();
      expect(bodies, isEmpty);

      signedIn = true;
      await service.flush();
      expect(bodies, isEmpty, reason: 'events from the signed-out period must not be sent later');
    });
  });

  testWidgets('flushes on its own after the delay', (tester) async {
    final service = build(flushDelay: const Duration(seconds: 10));

    service.track(1, ListingEventType.click);
    await tester.pump(const Duration(seconds: 9));
    expect(bodies, isEmpty);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(bodies, hasLength(1));
  });
}
