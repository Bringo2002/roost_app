import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roost_app/services/recent_searches_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RecentSearchesService', () {
    test('starts empty', () async {
      expect(await RecentSearchesService.getAll(), isEmpty);
    });

    test('add puts the newest query first', () async {
      await RecentSearchesService.add('kilimani');
      await RecentSearchesService.add('westlands');
      expect(await RecentSearchesService.getAll(), ['westlands', 'kilimani']);
    });

    test('re-adding an existing query (any case) moves it to the front instead of duplicating', () async {
      await RecentSearchesService.add('kilimani');
      await RecentSearchesService.add('westlands');
      await RecentSearchesService.add('Kilimani');
      expect(await RecentSearchesService.getAll(), ['Kilimani', 'westlands']);
    });

    test('blank queries are ignored', () async {
      await RecentSearchesService.add('   ');
      expect(await RecentSearchesService.getAll(), isEmpty);
    });

    test('entries are trimmed before storing', () async {
      await RecentSearchesService.add('  kilimani  ');
      expect(await RecentSearchesService.getAll(), ['kilimani']);
    });

    test('caps at 8 entries, dropping the oldest', () async {
      for (var i = 1; i <= 9; i++) {
        await RecentSearchesService.add('query$i');
      }
      final all = await RecentSearchesService.getAll();
      expect(all.length, 8);
      expect(all.first, 'query9');
      expect(all.contains('query1'), isFalse);
    });

    test('remove deletes just that entry', () async {
      await RecentSearchesService.add('kilimani');
      await RecentSearchesService.add('westlands');
      await RecentSearchesService.remove('kilimani');
      expect(await RecentSearchesService.getAll(), ['westlands']);
    });

    test('clear empties the list', () async {
      await RecentSearchesService.add('kilimani');
      await RecentSearchesService.clear();
      expect(await RecentSearchesService.getAll(), isEmpty);
    });

    test('a corrupt stored value is treated as empty rather than throwing', () async {
      SharedPreferences.setMockInitialValues({'recent_searches': 'not valid json'});
      expect(await RecentSearchesService.getAll(), isEmpty);
    });
  });
}
