import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [BaseCacheManager] that never touches the network, the disk or any
/// platform plugin: every image request fails immediately.
///
/// With it installed (see [useOfflineImages]) a `CachedNetworkImage` goes
/// straight to its error widget, so widget tests that show photos stay
/// hermetic and `pumpAndSettle` terminates. Only [getFileStream] is
/// implemented, which is the one call `CachedNetworkImage` makes for a plain
/// [BaseCacheManager]; any other member throws [UnimplementedError].
class OfflineCacheManager extends Fake implements BaseCacheManager {
  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => Stream<FileResponse>.error(Exception('Images are not available in widget tests: $url'));
}

/// Makes every `CachedNetworkImage` in the current test file fail to load
/// instead of reaching for the network.
///
/// Call it from `setUp`, before the first frame is pumped. It only assigns
/// [CachedNetworkImageProvider.defaultCacheManager] and never reads it: the
/// static's initializer constructs a `DefaultCacheManager`, which needs the
/// `path_provider` and `sqflite` plugins and throws `MissingPluginException`
/// in a test.
void useOfflineImages() {
  CachedNetworkImageProvider.defaultCacheManager = OfflineCacheManager();
}
