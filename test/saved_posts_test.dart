import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/local_database_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saved posts persist independently for each account', () async {
    final db = LocalDatabaseService();
    await db.savePostFavorite('alice', 'post-a', true);
    await db.savePostFavorite('bob', 'post-b', true);
    expect(await LocalDatabaseService().loadFavoritedPostIds('alice'), {
      'post-a',
    });
    expect(await db.loadFavoritedPostIds('bob'), {'post-b'});
    expect(await db.loadFavoritedPostIds('guest'), isEmpty);
  });

  test('removing a saved post does not affect another account', () async {
    final db = LocalDatabaseService();
    await db.savePostFavorite('alice', 'post', true);
    await db.savePostFavorite('bob', 'post', true);
    await db.savePostFavorite('alice', 'post', false);
    expect(await db.loadFavoritedPostIds('alice'), isEmpty);
    expect(await db.loadFavoritedPostIds('bob'), {'post'});
  });

  test('repeated saves are idempotent', () async {
    final db = LocalDatabaseService();
    await db.savePostFavorite('alice', 'post', true);
    await db.savePostFavorite('alice', 'post', true);
    expect(await db.loadFavoritedPostIds('alice'), {'post'});
  });

  test('legacy unowned bookmarks are not assigned to any account', () async {
    SharedPreferences.setMockInitialValues({
      'favorited_post_ids': ['old-post'],
    });
    expect(await LocalDatabaseService().loadFavoritedPostIds('alice'), isEmpty);
  });
}
