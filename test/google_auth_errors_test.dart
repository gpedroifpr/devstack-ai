import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/google_auth_errors.dart';
import 'package:flutter_application_1/services/app_database_service.dart';

void main() {
  test('cancelled popup offers another attempt', () {
    expect(
      googleAuthErrorMessage('popup-closed-by-user'),
      contains('cancelada'),
    );
    expect(
      googleAuthErrorMessage('cancelled-popup-request'),
      contains('cancelada'),
    );
  });
  test('configuration errors explain the required action', () {
    expect(googleAuthErrorMessage('popup-blocked'), contains('pop-ups'));
    expect(
      googleAuthErrorMessage('unauthorized-domain'),
      contains('autorizado'),
    );
    expect(
      googleAuthErrorMessage('operation-not-allowed'),
      contains('habilitado'),
    );
  });
  test('account conflict preserves original sign-in method', () {
    expect(
      googleAuthErrorMessage('account-exists-with-different-credential'),
      contains('método original'),
    );
  });
  test('unsupported platform does not create a local account', () async {
    final result = await AppDatabaseService().signInWithGoogle();
    expect(result.isSuccess, isFalse);
    expect(result.user, isNull);
  });
}
