import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/pages/search/property_detail_page.dart';
import 'package:roost_app/widgets/property/property_card.dart';

void main() {
  group('heroFlightCornerRadius', () {
    test('push: starts at the card radius, ends square', () {
      expect(
        heroFlightCornerRadius(HeroFlightDirection.push, 0),
        BorderRadius.circular(PropertyCard.cardCornerRadius),
      );
      expect(
        heroFlightCornerRadius(HeroFlightDirection.push, 1),
        BorderRadius.zero,
      );
    });

    test('push: is exactly halfway between rounded and square at t=0.5', () {
      expect(
        heroFlightCornerRadius(HeroFlightDirection.push, 0.5),
        BorderRadius.circular(PropertyCard.cardCornerRadius / 2),
      );
    });

    test('pop: is the exact mirror of push (starts square, ends at the card radius)', () {
      expect(
        heroFlightCornerRadius(HeroFlightDirection.pop, 0),
        BorderRadius.zero,
      );
      expect(
        heroFlightCornerRadius(HeroFlightDirection.pop, 1),
        BorderRadius.circular(PropertyCard.cardCornerRadius),
      );
      expect(
        heroFlightCornerRadius(HeroFlightDirection.pop, 0.5),
        BorderRadius.circular(PropertyCard.cardCornerRadius / 2),
      );
    });
  });
}
