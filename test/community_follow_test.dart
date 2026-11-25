import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/services/local_database_service.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('following persists and is isolated by account', () async {
    final database = LocalDatabaseService();
    await database.setCommunityFollowed('alice', 'flutter', true);
    expect(await LocalDatabaseService().loadFollowedCommunityIds('alice'), {
      'flutter',
    });
    expect(await database.loadFollowedCommunityIds('bob'), isEmpty);
  });

  test(
    'following twice does not duplicate and unfollowing removes only its ID',
    () async {
      final database = LocalDatabaseService();
      await database.setCommunityFollowed('alice', 'flutter', true);
      await database.setCommunityFollowed('alice', 'flutter', true);
      await database.setCommunityFollowed('alice', 'dart', true);
      expect(await database.loadFollowedCommunityIds('alice'), {
        'flutter',
        'dart',
      });
      await database.setCommunityFollowed('alice', 'flutter', false);
      expect(await database.loadFollowedCommunityIds('alice'), {'dart'});
    },
  );

  test('shared community data never determines the account follow state', () {
    final community = Community.fromJson({'id': 'flutter', 'isFollowed': true});
    expect(community.isFollowed, isFalse);
    community.isFollowed = true;
    expect(community.toJson().containsKey('isFollowed'), isFalse);
  });
}
