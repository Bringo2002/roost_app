import 'package:flutter_test/flutter_test.dart';

import 'package:roost_app/widgets/common/full_screen_image_gallery.dart';

void main() {
  group('shouldDismissPhotoViewer', () {
    test('a short, slow drag snaps back', () {
      expect(shouldDismissPhotoViewer(dragDistance: 40, velocityY: 0), isFalse);
    });

    test('dismisses once dragged exactly to the distance threshold', () {
      expect(
        shouldDismissPhotoViewer(dragDistance: photoViewerDismissDistance, velocityY: 0),
        isTrue,
      );
    });

    test('just under the distance threshold snaps back', () {
      expect(
        shouldDismissPhotoViewer(dragDistance: photoViewerDismissDistance - 1, velocityY: 0),
        isFalse,
      );
    });

    test('a downward fling at the velocity threshold dismisses after a short drag', () {
      expect(
        shouldDismissPhotoViewer(dragDistance: 10, velocityY: photoViewerDismissFlingVelocity),
        isTrue,
      );
    });

    test('just under the fling velocity does not dismiss on its own', () {
      expect(
        shouldDismissPhotoViewer(dragDistance: 10, velocityY: photoViewerDismissFlingVelocity - 1),
        isFalse,
      );
    });

    test('a hard upward fling cancels even a drag past the distance threshold', () {
      expect(
        shouldDismissPhotoViewer(dragDistance: 200, velocityY: -photoViewerDismissFlingVelocity),
        isFalse,
      );
    });

    test('a gentle upward drift after a long drag still dismisses', () {
      expect(shouldDismissPhotoViewer(dragDistance: 200, velocityY: -100), isTrue);
    });
  });
}
