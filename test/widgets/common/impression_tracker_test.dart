import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roost_app/services/listing_event_service.dart';
import 'package:roost_app/widgets/common/impression_tracker.dart';

void main() {
  late List<int> reported;
  late List<ListingEventSource?> sources;

  Widget host({
    required int? id,
    bool mounted = true,
    Key? key,
    ListingEventSource? source,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: mounted
          ? ImpressionTracker(
              key: key,
              propertyId: id,
              source: source,
              onImpression: (id, source) {
                reported.add(id);
                sources.add(source);
              },
              child: const SizedBox(),
            )
          : const SizedBox(),
    );
  }

  setUp(() {
    reported = [];
    sources = [];
  });

  testWidgets('reports once after the dwell time, not before', (tester) async {
    await tester.pumpWidget(host(id: 7));

    await tester.pump(const Duration(milliseconds: 900));
    expect(reported, isEmpty);

    await tester.pump(const Duration(milliseconds: 200));
    expect(reported, [7]);

    await tester.pump(const Duration(seconds: 5));
    expect(reported, [7], reason: 'must not report again while staying mounted');
  });

  testWidgets('a card removed before the dwell elapses is never reported', (tester) async {
    await tester.pumpWidget(host(id: 7));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.pumpWidget(host(id: 7, mounted: false));
    await tester.pump(const Duration(seconds: 5));

    expect(reported, isEmpty);
  });

  testWidgets('a null property id is never reported', (tester) async {
    await tester.pumpWidget(host(id: null));

    await tester.pump(const Duration(seconds: 5));

    expect(reported, isEmpty);
  });

  testWidgets('switching to another listing restarts the dwell for the new one', (tester) async {
    const key = ValueKey('slot');
    await tester.pumpWidget(host(id: 1, key: key));
    await tester.pump(const Duration(milliseconds: 800));

    await tester.pumpWidget(host(id: 2, key: key));
    await tester.pump(const Duration(milliseconds: 800));
    expect(reported, isEmpty, reason: 'listing 2 has only been shown for 0.8s');

    await tester.pump(const Duration(milliseconds: 300));
    expect(reported, [2], reason: 'listing 1 never reached its dwell time');
  });

  testWidgets('reports the feed the card belongs to', (tester) async {
    await tester.pumpWidget(host(id: 7, source: ListingEventSource.search));

    await tester.pump(const Duration(seconds: 2));

    expect(sources, [ListingEventSource.search]);
  });

  testWidgets('the same listing moving to another feed is a new impression', (tester) async {
    const key = ValueKey('slot');
    await tester.pumpWidget(host(id: 7, key: key, source: ListingEventSource.search));
    await tester.pump(const Duration(seconds: 2));

    await tester.pumpWidget(
        host(id: 7, key: key, source: ListingEventSource.searchRecommended));
    await tester.pump(const Duration(seconds: 2));

    expect(reported, [7, 7]);
    expect(sources,
        [ListingEventSource.search, ListingEventSource.searchRecommended]);
  });
}
