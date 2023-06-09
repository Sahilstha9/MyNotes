import 'package:mynotes/services/auth/auth_exception.dart';
import 'package:mynotes/services/auth/auth_provider.dart';
import 'package:mynotes/services/auth/auth_user.dart';
import 'package:test/test.dart';

void main() {
  group('Mock Authentication', () {
    final provider = MockAuthProvider();

    test('Should not be initialized to begin with', () {
      expect(provider.isInitalized, false);
    });

    test('Cannot log out if not initalized', () {
      expect(
        provider.logOut(),
        throwsA(const TypeMatcher<NotInitalizedException>()),
      );
    });

    test('Should be able to be initialied', () async {
      await provider.initialize();
      expect(provider.isInitalized, true);
    });

    test('User should be null after initialization', () async {
      expect(provider.currentUser, null);
    });

    test('Should be able to initalize in less than 2 seconds', () async {
      await provider.initialize();
      expect(provider.isInitalized, true);
    }, timeout: const Timeout(Duration(seconds: 2)));

    test('Create user should delegate to LogIn function', () async {
      final badUser =
          provider.createUser(email: 'foo@bar.com', password: '123rufsdg');

      expect(badUser, throwsA(const TypeMatcher<UserNoteFoundAuthException>()));

      final badPasswordUser =
          provider.createUser(email: 'fdsa@bar.com', password: 'foo');

      expect(badPasswordUser,
          throwsA(const TypeMatcher<WrongPasswordAuthException>()));

      final user = await provider.createUser(
          email: 'some@foo.com', password: 'fsddhgfdj');

      expect(provider.currentUser, user);

      expect(user.isEmailVerified, false);
    });

    test('Logged In user should be able to be verified', () {
      provider.sendEmailVerification();
      final user = provider.currentUser;
      expect(user, isNotNull);
      expect(user!.isEmailVerified, true);
    });

    test('should be able to logout and login again', () async {
      await provider.logOut();
      await provider.logIn(email: 'email', password: 'password');

      final user = provider.currentUser;

      expect(user, isNotNull);
    });
  });
}

class NotInitalizedException implements Exception {}

class MockAuthProvider implements AuthProvider {
  AuthUser? _user;
  var _isInitialized = false;
  bool get isInitalized => _isInitialized;

  @override
  Future<AuthUser> createUser({
    required String email,
    required String password,
  }) async {
    if (!isInitalized) throw NotInitalizedException();
    await Future.delayed(const Duration(seconds: 1));

    return logIn(email: email, password: password);
  }

  @override
  // TODO: implement currentUser
  AuthUser? get currentUser => _user;

  @override
  Future<void> initialize() async {
    await Future.delayed(const Duration(seconds: 1));
    _isInitialized = true;
  }

  @override
  Future<AuthUser> logIn({
    required String email,
    required String password,
  }) async {
    if (!isInitalized) throw NotInitalizedException();
    if (email == 'foo@bar.com') throw UserNoteFoundAuthException();
    if (password == 'foo') throw WrongPasswordAuthException();

    const user = AuthUser(email: 'foo@bar.com', isEmailVerified: false);
    _user = user;

    return Future.value(user);
  }

  @override
  Future<void> logOut() async {
    if (!isInitalized) throw NotInitalizedException();
    if (_user == null) throw UserNoteLoggedInAuthException();

    await Future.delayed(const Duration(seconds: 1));
    _user = null;
  }

  @override
  Future<void> sendEmailVerification() async {
    if (!isInitalized) throw NotInitalizedException();
    final user = _user;
    if (user == null) throw UserNoteFoundAuthException();

    const newUser = AuthUser(isEmailVerified: true, email: 'foo@bar.com');
    _user = newUser;
  }
}
