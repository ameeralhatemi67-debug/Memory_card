import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_card/data/store.dart';
import 'package:memory_card/data/store_scope.dart';
import 'package:memory_card/features/account/sign_in_sheet.dart';
import 'package:memory_card/features/profile/profile_screen.dart';
import 'package:memory_card/services/account.dart';
import 'package:memory_card/ui/overlays.dart';
import 'package:memory_card/ui/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// An account server in memory: the sign-in screens and the account rules, without the network.
class FakeAuth implements AuthBackend {
  final _changes = StreamController<AccountUser?>.broadcast();
  final _recovery = StreamController<void>.broadcast();
  final Map<String, (String pw, String name, bool confirmed)> accounts = {};
  AccountUser? _current;
  AuthProviders served = const AuthProviders(email: true, google: false, apple: false);
  bool autoConfirm = false;
  bool googleCancels = false;
  final List<String> calls = [];

  void _set(AccountUser? u) {
    _current = u;
    _changes.add(u);
  }

  @override
  bool get configured => true;
  @override
  Future<void> init() async {}
  @override
  AccountUser? get current => _current;
  @override
  Stream<AccountUser?> get changes => _changes.stream;
  @override
  Stream<void> get recovery => _recovery.stream;
  @override
  Future<AuthProviders> providers() async => served;

  @override
  Future<AuthStep> signUp({required String name, required String email, required String password}) async {
    calls.add('signUp $email');
    if (accounts.containsKey(email)) throw const AuthFailure('There is already an account with that email. Sign in instead.');
    accounts[email] = (password, name, autoConfirm);
    if (!autoConfirm) return AuthStep.confirmEmail;
    _set(AccountUser(id: 'u-$email', email: email, name: name, provider: 'email'));
    return AuthStep.done;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    calls.add('signIn $email');
    final a = accounts[email];
    if (a == null || a.$1 != password) throw const AuthFailure('That email and password do not match an account.');
    if (!a.$3) throw const AuthFailure('Confirm your email address first: open the link we sent you.', needsConfirm: true);
    _set(AccountUser(id: 'u-$email', email: email, name: a.$2, provider: 'email'));
  }

  @override
  Future<AuthStep> signInWithGoogle() async {
    calls.add('google');
    if (googleCancels) return AuthStep.cancelled;
    _set(const AccountUser(id: 'g1', email: 'ada@gmail.com', name: 'Ada Lovelace', provider: 'google'));
    return AuthStep.done;
  }

  @override
  Future<AuthStep> signInWithApple() async {
    calls.add('apple');
    return AuthStep.browser;
  }

  @override
  Future<void> resendConfirmation(String email) async => calls.add('resend $email');
  @override
  Future<void> verifyEmailCode({required String email, required String code}) async {
    calls.add('code $email $code');
    final a = accounts[email]!;
    accounts[email] = (a.$1, a.$2, true);
    _set(AccountUser(id: 'u-$email', email: email, name: a.$2, provider: 'email'));
  }

  @override
  Future<void> sendPasswordReset(String email) async => calls.add('reset $email');
  @override
  Future<void> resetWithCode({required String email, required String code, required String password}) async =>
      calls.add('resetCode $email $code');
  @override
  Future<void> changePassword(String password) async => calls.add('password');
  @override
  Future<void> rename(String name) async {
    calls.add('rename $name');
    final u = _current;
    if (u != null) _set(AccountUser(id: u.id, email: u.email, name: name, provider: u.provider));
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    _set(null);
  }

  @override
  Future<void> deleteAccount() async {
    calls.add('delete');
    _set(null);
  }

  /// A browser sign-in (Apple on Android) coming back through the app link.
  void finishBrowser() => _set(const AccountUser(id: 'a1', email: 'x@privaterelay.appleid.com', name: '', provider: 'apple'));
}

/// Steps time forward without waiting for every animation to stop (spinners never do).
Future<void> settle(WidgetTester tester, [int ms = 900]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late FakeAuth fake;
  late AppStore store;

  setUpAll(() async {
    T.googleFonts = false;
    TestWidgetsFlutterBinding.ensureInitialized();
    store = await AppStore.open(path: Directory.systemTemp.createTempSync('mc_account_').path);
  });

  /// A fresh account server, started in the calling test's zone (widget tests run on a fake clock).
  Future<void> fresh({AuthProviders served = const AuthProviders(email: true)}) async {
    fake = FakeAuth()..served = served;
    Account.i.useBackend(fake);
    await Account.i.init();
    Account.i.attach(store);
  }

  setUp(() => store.updateSettings((s) => s.name = ''));

  group('form checks', () {
    test('email and password', () {
      expect(Account.checkEmail(''), isNotNull);
      expect(Account.checkEmail('ada'), isNotNull);
      expect(Account.checkEmail('ada@home'), isNotNull);
      expect(Account.checkEmail(' ada@example.com '), isNull);
      expect(Account.checkPassword('short'), isNotNull);
      expect(Account.checkPassword('        '), isNotNull);
      expect(Account.checkPassword('long enough'), isNull);
    });

    test('server errors read like the app', () {
      expect(SupabaseAuth.explain(const sb.AuthException('Invalid login credentials', code: 'invalid_credentials')).message,
          contains('do not match'));
      final unconfirmed = SupabaseAuth.explain(const sb.AuthException('Email not confirmed', code: 'email_not_confirmed'));
      expect(unconfirmed.needsConfirm, isTrue);
      expect(SupabaseAuth.explain(const sb.AuthException('User already registered', code: 'user_already_exists')).message,
          contains('already an account'));
      expect(SupabaseAuth.explain(const sb.AuthException('slow down', code: 'over_email_send_rate_limit')).message, contains('Too many'));
      expect(SupabaseAuth.explain(const sb.AuthException('Unsupported provider: provider is not enabled')).message, contains('not switched on'));
    });
  });

  group('account and the card name', () {
    test('signing in fills an empty card name; a named card names a nameless account', () async {
      await fresh();
      fake.autoConfirm = true;
      await Account.i.signUp(name: 'Grace', email: 'grace@example.com', password: 'compilers1');
      await Future<void>.delayed(Duration.zero);
      expect(Account.i.user.value!.name, 'Grace');
      expect(store.settings.name, 'Grace');
      await Account.i.signOut();
      expect(Account.i.user.value, isNull);
      expect(store.settings.name, 'Grace', reason: 'signing out never erases anything on the phone');

      store.updateSettings((s) => s.name = 'Captain');
      fake.finishBrowser(); // an Apple account with no name
      await Future<void>.delayed(Duration.zero);
      expect(fake.calls, contains('rename Captain'));
    });
  });

  group('sign-in sheet', () {
    Future<void> open(WidgetTester tester, {bool create = false, String? start}) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(StoreScope(
        store: store,
        child: MaterialApp(
          theme: Mc.theme(Mc.light),
          home: Scaffold(
            body: Stack(children: [
              Builder(
                builder: (context) => Center(
                  child: TextButton(onPressed: () => showSignInSheet(context, create: create, start: start), child: const Text('open')),
                ),
              ),
              const ToastHost(bottom: 40),
            ]),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await settle(tester);
    }

    Future<void> done(WidgetTester tester) async {
      Toaster.i.hide();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    }

    testWidgets('email sign-in: wrong password says so, the right one signs in and closes', (tester) async {
      await fresh();
      fake.accounts['ada@example.com'] = ('engines1', 'Ada', true);
      await open(tester);
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('SOON'), findsNWidgets(2), reason: 'both are off on the server');

      await tester.enterText(find.byType(TextField).at(0), 'ada@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'wrong-one');
      await tester.tap(find.text('Sign in').last);
      await settle(tester);
      expect(find.textContaining('do not match'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(1), 'engines1');
      await tester.tap(find.text('Sign in').last);
      await settle(tester);
      expect(Account.i.user.value?.email, 'ada@example.com');
      expect(find.text('Continue with Apple'), findsNothing, reason: 'the sheet closed');
      await done(tester);
    });

    testWidgets('create an account → check your email → the code signs you in', (tester) async {
      await fresh();
      await open(tester, create: true);
      expect(find.text('Create your account'), findsOneWidget);
      await tester.tap(find.text('Create my account'));
      await settle(tester);
      expect(find.text('Your name'), findsWidgets);

      await tester.enterText(find.byType(TextField).at(0), 'Alan');
      await tester.enterText(find.byType(TextField).at(1), 'alan@example.com');
      await tester.enterText(find.byType(TextField).at(2), 'enigma123');
      await tester.tap(find.text('Create my account'));
      await settle(tester);
      expect(find.text('Check your email'), findsOneWidget);

      await tester.tap(find.text('Send the email again'));
      await settle(tester);
      expect(fake.calls, contains('resend alan@example.com'));

      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pump();
      await tester.tap(find.text('Confirm the code'));
      await settle(tester);
      expect(fake.calls, contains('code alan@example.com 123456'));
      expect(Account.i.user.value?.name, 'Alan');
      await done(tester);
    });

    testWidgets('Google and Apple: off on the server says so; on, Google signs in and Apple waits for the browser',
        (tester) async {
      await fresh();
      await open(tester);
      await tester.tap(find.text('Continue with Google'));
      await settle(tester);
      expect(find.textContaining('not switched on'), findsOneWidget);
      expect(fake.calls, isNot(contains('google')));
      await done(tester);

      await fresh(served: const AuthProviders(email: true, google: true, apple: true));
      await open(tester, start: 'apple');
      await settle(tester);
      expect(find.text('Finish in your browser'), findsOneWidget);
      fake.finishBrowser();
      await settle(tester);
      expect(Account.i.user.value?.provider, 'apple');
      await done(tester);
    });

    testWidgets('forgot password: send the email, then the code and a new password', (tester) async {
      await fresh();
      await open(tester);
      await tester.tap(find.text('Forgot your password?'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).first, 'ada@example.com');
      await tester.tap(find.text('Send the email'));
      await settle(tester);
      expect(fake.calls, contains('reset ada@example.com'));
      expect(find.text('Set a new password'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), '654321');
      await tester.enterText(find.byType(TextField).at(1), 'brand-new-pw');
      await tester.tap(find.text('Save the new password'));
      await settle(tester);
      expect(fake.calls, contains('resetCode ada@example.com 654321'));
      await done(tester);
    });
  });

  testWidgets('the Account tab shows who is signed in, and the account sheet signs out', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await fresh();
    await tester.pumpWidget(StoreScope(
      store: store,
      child: MaterialApp(theme: Mc.theme(Mc.light), home: const Stack(children: [ProfileScreen(), ToastHost(bottom: 40)])),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Have an account? '), findsNothing); // a rich text span: look for the badges instead
    expect(find.bySemanticsLabel('Sign in with Google'), findsOneWidget);

    fake.accounts['ada@example.com'] = ('engines1', 'Ada', true);
    await Account.i.signIn(email: 'ada@example.com', password: 'engines1');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Signed in'), findsOneWidget);
    expect(find.text('ada@example.com'), findsOneWidget);

    await tester.tap(find.text('Signed in'));
    await settle(tester);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await settle(tester);
    expect(Account.i.user.value, isNull);
    expect(find.bySemanticsLabel('Sign in with Google'), findsOneWidget);

    Toaster.i.hide();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
