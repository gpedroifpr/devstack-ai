import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/models/post_update.dart';
import 'package:flutter_application_1/services/local_database_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'updates only editable fields and preserves publication metadata',
    () async {
      final db = LocalDatabaseService();
      await db.saveUserPost({
        'id': 'post',
        'authorId': 'alice',
        'title': 'Titulo antigo',
        'description': 'Descricao anterior',
        'code': 'old()',
        'likes': 7,
        'comments': 3,
        'communityId': 'flutter',
        'createdAtLocal': '2026-01-01',
      });
      await db.updateUserPost(
        'alice',
        'post',
        const PostUpdate(
          title: '  Novo titulo  ',
          description: 'Uma nova descricao',
          code: 'new()',
          isResolved: true,
        ),
      );
      final posts = await db.loadUserPosts();
      expect(posts, hasLength(1));
      expect(posts.single['title'], 'Novo titulo');
      expect(posts.single['authorId'], 'alice');
      expect(posts.single['likes'], 7);
      expect(posts.single['comments'], 3);
      expect(posts.single['communityId'], 'flutter');
      expect(posts.single['createdAtLocal'], '2026-01-01');
      expect(posts.single['isResolved'], true);
      await db.updateUserPost(
        'alice',
        'post',
        const PostUpdate(isResolved: false),
      );
      expect((await db.loadUserPosts()).single['isResolved'], false);
    },
  );
  test('another account cannot modify a publication', () async {
    final db = LocalDatabaseService();
    await db.saveUserPost({
      'id': 'post',
      'authorId': 'alice',
      'title': 'Original',
    });
    await expectLater(
      db.updateUserPost('bob', 'post', const PostUpdate(isResolved: true)),
      throwsStateError,
    );
    expect((await db.loadUserPosts()).single.containsKey('isResolved'), false);
  });
  test('missing publication cannot be recreated through editing', () async {
    await expectLater(
      LocalDatabaseService().updateUserPost(
        'alice',
        'missing',
        const PostUpdate(isResolved: true),
      ),
      throwsStateError,
    );
  });
  test('validation rejects invalid content and limits update fields', () {
    expect(() => const PostUpdate(title: 'a').toJson(), throwsArgumentError);
    expect(
      () => const PostUpdate(description: 'short').toJson(),
      throwsArgumentError,
    );
    expect(() => PostUpdate(code: 'a' * 20001).toJson(), throwsArgumentError);
    expect(const PostUpdate(isResolved: true).toJson(), {'isResolved': true});
  });
}
