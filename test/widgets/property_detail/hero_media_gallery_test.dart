import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/widgets/property_detail/hero_media_gallery.dart';

void main() {
  group('propertyPhotoHeroTag', () {
    test('is stable, so the thumbnail and the viewer agree on it', () {
      expect(propertyPhotoHeroTag(7, 2), propertyPhotoHeroTag(7, 2));
    });

    test('differs per photo of the same property', () {
      expect(propertyPhotoHeroTag(7, 0), isNot(propertyPhotoHeroTag(7, 1)));
    });

    test('differs per property for the same photo index', () {
      expect(propertyPhotoHeroTag(7, 0), isNot(propertyPhotoHeroTag(8, 0)));
    });

    test('keeps property 1 / photo 11 apart from property 11 / photo 1', () {
      expect(propertyPhotoHeroTag(1, 11), isNot(propertyPhotoHeroTag(11, 1)));
    });

    test('never equals the listing card Hero tag for the same property', () {
      expect(propertyPhotoHeroTag(7, 0), isNot('property-image-7'));
    });
  });
}
