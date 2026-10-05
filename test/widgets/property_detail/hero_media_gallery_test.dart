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

  group('slideIndexForPhoto', () {
    test('is the photo index when there is no video', () {
      expect(slideIndexForPhoto(0, hasVideo: false), 0);
      expect(slideIndexForPhoto(3, hasVideo: false), 3);
    });

    test('shifts every photo along by one when the video takes slide 0', () {
      expect(slideIndexForPhoto(0, hasVideo: true), 1);
      expect(slideIndexForPhoto(3, hasVideo: true), 4);
    });
  });
}
