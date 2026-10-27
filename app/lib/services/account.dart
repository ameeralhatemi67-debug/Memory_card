import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient, Platform;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../data/store.dart';
import 'backend_config.dart';

/// The person signed in on this phone.
@immutable
class AccountUser {
  const AccountUser({required this.id, required this.email, required this.name, required this.provider});

  final String id;
  final String email;

  /// The name on the membership card ('' when the account has none yet).
  final String name;

  /// How they signed in: email · google · apple.
  final String provider;

  String get providerName => switch (provider) { 'google' => 'Google', 'apple' => 'Apple', _ => 'email and password' };

  @override
  bool operator ==(Object other) =>
      other is AccountUser && other.id == id && other.email == email && other.name == name && other.provider == provider;

  @override
  int get hashCode => Object.hash(id, email, name, provider);
}

/// Something the person can act on went wrong: [message] is said to them as it is.
class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.needsConfirm = false});
  final String message;

  /// The account exists but its email address is not confirmed yet.
  final bool needsConfirm;

  @override
  String toString() => message;
}

/// How a sign-in attempt ended.
enum AuthStep {
  /// Signed in.
  done,

  /// The person backed out (closed the account picker).
  cancelled,

  /// It goes on in the browser; the session arrives through [Account.user] when it comes back.
  browser,

  /// A new account waits for its email address to be confirmed.
  confirmEmail,
}

/// Which ways of signing in the server has switched on (read from it, so the app never offers a dead end).
@immutable
class AuthProviders {
  const AuthProviders({this.email = true, this.google = false, this.apple = false, this.autoConfirm = false});

  final bool email;
  final bool google;
  final bool apple;

  /// New email accounts can sign in right away (no confirmation email).
  final bool autoConfirm;

  static const unknown = AuthProviders();
}

/// What the app needs from an account server. [SupabaseAuth] is the real one; tests use a fake.
abstract class AuthBackend {
  bool get configured;
  Future<void> init();
  AccountUser? get current;
  Stream<AccountUser?> get changes;

  /// A password reset link from an email brought the person back: they may set a new password now.
  Stream<void> get recovery;
  Future<AuthProviders> providers();
  Future<AuthStep> signUp({required String name, required String email, required String password});
  Future<void> signIn({required String email, required String password});
  Future<AuthStep> signInWithGoogle();
  Future<AuthStep> signInWithApple();
  Future<void> resendConfirmation(String email);
  Future<void> verifyEmailCode({required String email, required String code});
  Future<void> sendPasswordReset(String email);
  Future<void> resetWithCode({required String email, required String code, required String password});
  Future<void> changePassword(String password);
  Future<void> rename(String name);
  Future<void> signOut();
  Future<void> deleteAccount();
}

/// Accounts: optional, and the app works fully without one. Signing in puts your name on the membership
/// card and is the first step toward keeping your library across phones.
class Account {
  Account._();
  static final i = Account._();

  AuthBackend backend = SupabaseAuth();

  /// Who is signed in (null = nobody, the default).
  final ValueNotifier<AccountUser?> user = ValueNotifier(null);

  /// Fires when a password-reset link opened the app: the sheet then asks for the new password.
  final StreamController<void> _recovery = StreamController.broadcast();
  Stream<void> get recovery => _recovery.stream;

  Future<void>? _ready;
  AppStore? _store;
  AuthProviders? _providers;

  bool get configured => backend.configured;

  /// Starts the account server's client once (it restores the last session from the phone).
  Future<void> init() => _ready ??= _init();

  final List<StreamSubscription<Object?>> _subs = [];

  Future<void> _init() async {
    if (!backend.configured) return;
    try {
      await backend.init();
      user.value = backend.current;
      _subs
        ..add(backend.changes.listen((u) {
          user.value = u;
          if (u != null) _syncName(u);
        }))
        ..add(backend.recovery.listen((_) => _recovery.add(null)));
    } catch (e) {
      debugPrint('Memory Card accounts unavailable: $e');
    }
  }

  /// Tests: start over with [b] (the next [init] runs again, in the caller's zone).
  @visibleForTesting
  void useBackend(AuthBackend b) {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    backend = b;
    _ready = null;
    _providers = null;
    user.value = null;
  }

  /// Keeps the card's name and the account's name together.
  void attach(AppStore store) {
    _store = store;
    final u = user.value;
    if (u != null) _syncName(u);
  }

  void _syncName(AccountUser u) {
    final store = _store;
    if (store == null) return;
    final local = store.settings.name.trim();
    if (local.isEmpty && u.name.isNotEmpty) {
      store.updateSettings((s) => s.name = u.name);
    } else if (u.name.isEmpty && local.isNotEmpty) {
      unawaited(backend.rename(local).catchError((Object _) {}));
    }
  }

  Future<T> _run<T>(Future<T> Function() f) async {
    if (!backend.configured) throw const AuthFailure('Accounts are not set up in this build of the app.');
    await init();
    try {
      return await f();
    } on AuthFailure {
      rethrow;
    } on sb.AuthException catch (e) {
      throw SupabaseAuth.explain(e);
    } on TimeoutException {
      throw const AuthFailure('The account server did not answer. Check your connection and try again.');
    } catch (e) {
      final s = '$e';
      if (s.contains('SocketException') || s.contains('Failed host lookup') || s.contains('ClientException')) {
        throw const AuthFailure('No connection. Accounts need the internet; the rest of the app does not.');
      }
      debugPrint('Memory Card account error: $e');
      throw const AuthFailure('Something went wrong. Please try again.');
    }
  }

  /// Which sign-in buttons work, asked once per launch (falls back to email only when offline).
  Future<AuthProviders> providers() async {
    final cached = _providers;
    if (cached != null) return cached;
    try {
      await init();
      return _providers = await backend.providers();
    } catch (_) {
      return AuthProviders.unknown;
    }
  }

  Future<AuthStep> signUp({required String name, required String email, required String password}) =>
      _run(() => backend.signUp(name: name.trim(), email: email.trim(), password: password));

  Future<void> signIn({required String email, required String password}) =>
      _run(() => backend.signIn(email: email.trim(), password: password));

  Future<AuthStep> signInWithGoogle() => _run(backend.signInWithGoogle);
  Future<AuthStep> signInWithApple() => _run(backend.signInWithApple);
  Future<void> resendConfirmation(String email) => _run(() => backend.resendConfirmation(email.trim()));
  Future<void> verifyEmailCode({required String email, required String code}) =>
      _run(() => backend.verifyEmailCode(email: email.trim(), code: code.trim()));
  Future<void> sendPasswordReset(String email) => _run(() => backend.sendPasswordReset(email.trim()));
  Future<void> resetWithCode({required String email, required String code, required String password}) =>
      _run(() => backend.resetWithCode(email: email.trim(), code: code.trim(), password: password));
  Future<void> changePassword(String password) => _run(() => backend.changePassword(password));

  Future<void> rename(String name) async {
    if (user.value == null) return;
    await _run(() => backend.rename(name.trim()));
  }

  /// Signs out on this phone. Nothing on the phone is erased: decks and progress stay.
  Future<void> signOut() => _run(backend.signOut);

  /// Deletes the account on the server for good. Decks and progress on this phone stay.
  Future<void> deleteAccount() => _run(backend.deleteAccount);

  // ---------------------------------------------------------------- checks the forms use

  static final _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

  static String? checkEmail(String v) {
    final e = v.trim();
    if (e.isEmpty) return 'Your email address';
    if (!_emailShape.hasMatch(e)) return 'That does not look like an email address';
    return null;
  }

  static const minPassword = 8;

  static String? checkPassword(String v) {
    if (v.isEmpty) return 'Choose a password';
    if (v.length < minPassword) return 'At least $minPassword characters';
    if (v.trim().isEmpty) return 'A password cannot be only spaces';
    return null;
  }
}

/// The real account server: Supabase Auth, with Google's and Apple's own sign-in sheets where the phone has
/// them (the browser otherwise).
class SupabaseAuth implements AuthBackend {
  sb.GoTrueClient get _auth => sb.Supabase.instance.client.auth;
  bool _googleReady = false;
  final _recovery = StreamController<void>.broadcast();

  @override
  bool get configured => BackendConfig.configured;

  @override
  Future<void> init() async {
    await sb.Supabase.initialize(
      url: BackendConfig.supabaseUrl,
      publishableKey: BackendConfig.publishableKey,
      authOptions: sb.FlutterAuthClientOptions(
        authFlowType: sb.AuthFlowType.pkce,
        // Only our own callback carries a session: widget taps (memorycard://…) are left alone.
        detectSessionInUriPredicate: (uri) => uri.scheme == BackendConfig.callbackScheme,
      ),
      debug: false,
    );
    _auth.onAuthStateChange.listen((s) {
      if (s.event == sb.AuthChangeEvent.passwordRecovery) _recovery.add(null);
    }, onError: (Object _) {});
  }

  static AccountUser? _user(sb.User? u) {
    if (u == null) return null;
    final meta = u.userMetadata ?? const {};
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = meta[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return '';
    }

    final provider = u.appMetadata['provider'];
    return AccountUser(
      id: u.id,
      email: u.email ?? '',
      name: pick(const ['display_name', 'full_name', 'name']),
      provider: provider is String && provider != 'email' ? provider : 'email',
    );
  }

  @override
  AccountUser? get current => _user(_auth.currentUser);

  @override
  Stream<AccountUser?> get changes => _auth.onAuthStateChange.map((s) => _user(s.session?.user ?? _auth.currentUser));

  @override
  Stream<void> get recovery => _recovery.stream;

  @override
  Future<AuthProviders> providers() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final req = await client.getUrl(Uri.parse('${BackendConfig.supabaseUrl}/auth/v1/settings'));
      req.headers.set('apikey', BackendConfig.publishableKey);
      final res = await req.close().timeout(const Duration(seconds: 8));
      final body = await res.transform(utf8.decoder).join();
      final j = jsonDecode(body);
      final ext = j is Map ? j['external'] : null;
      if (ext is! Map) return AuthProviders.unknown;
      return AuthProviders(
        email: ext['email'] == true,
        google: ext['google'] == true && BackendConfig.googleWebClientId.isNotEmpty,
        apple: ext['apple'] == true,
        autoConfirm: j['mailer_autoconfirm'] == true,
      );
    } finally {
      client.close(force: true);
    }
  }

  /// Supabase's errors, said the way the rest of the app talks.
  static AuthFailure explain(sb.AuthException e) {
    final code = e.code ?? '';
    final m = e.message.toLowerCase();
    if (code == 'invalid_credentials' || m.contains('invalid login')) {
      return const AuthFailure('That email and password do not match an account.');
    }
    if (code == 'email_not_confirmed' || m.contains('not confirmed')) {
      return const AuthFailure('Confirm your email address first: open the link we sent you.', needsConfirm: true);
    }
    if (code == 'user_already_exists' || code == 'email_exists' || m.contains('already registered')) {
      return const AuthFailure('There is already an account with that email. Sign in instead.');
    }
    if (code == 'weak_password' || m.contains('password should')) {
      return const AuthFailure('Pick a stronger password: longer, with a mix of letters and numbers.');
    }
    if (code == 'same_password') return const AuthFailure('That is your current password. Choose a new one.');
    if (code == 'otp_expired' || m.contains('expired') || m.contains('invalid otp') || m.contains('token has expired')) {
      return const AuthFailure('That code is wrong or has expired. Ask for a new email.');
    }
    if (code.contains('rate_limit') || e.statusCode == '429') {
      return const AuthFailure('Too many tries for now. Wait a minute and try again.');
    }
    if (code == 'email_address_invalid') return const AuthFailure('That email address cannot be used.');
    if (code == 'signup_disabled') return const AuthFailure('New accounts are closed for now.');
    if (code == 'provider_disabled' || m.contains('provider is not enabled')) {
      return const AuthFailure('That way of signing in is not switched on yet.');
    }
    if (m.contains('session')) return const AuthFailure('You were signed out. Sign in again.');
    return AuthFailure(e.message);
  }

  @override
  Future<AuthStep> signUp({required String name, required String email, required String password}) async {
    final r = await _auth
        .signUp(email: email, password: password, data: {'display_name': name}, emailRedirectTo: BackendConfig.callbackUrl)
        .timeout(const Duration(seconds: 20));
    // An existing, confirmed address comes back as a user with no identities (Supabase hides that it exists).
    if (r.session == null && (r.user?.identities?.isEmpty ?? false)) {
      throw const AuthFailure('There is already an account with that email. Sign in instead.');
    }
    return r.session != null ? AuthStep.done : AuthStep.confirmEmail;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithPassword(email: email, password: password).timeout(const Duration(seconds: 20));
  }

  @override
  Future<AuthStep> signInWithGoogle() async {
    if (BackendConfig.googleWebClientId.isEmpty) {
      throw const AuthFailure('Google sign-in is not switched on in this build yet.');
    }
    final g = GoogleSignIn.instance;
    if (!_googleReady) {
      await g.initialize(
        serverClientId: BackendConfig.googleWebClientId,
        clientId: !kIsWeb && Platform.isIOS && BackendConfig.googleIosClientId.isNotEmpty ? BackendConfig.googleIosClientId : null,
      );
      _googleReady = true;
    }
    try {
      final account = await g.authenticate(scopeHint: const ['email', 'profile']);
      final idToken = account.authentication.idToken;
      if (idToken == null) throw const AuthFailure('Google did not hand over a sign-in token. Try again.');
      await _auth.signInWithIdToken(provider: sb.OAuthProvider.google, idToken: idToken).timeout(const Duration(seconds: 20));
      final name = account.displayName?.trim() ?? '';
      if (name.isNotEmpty && (current?.name ?? '').isEmpty) await rename(name);
      return AuthStep.done;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return AuthStep.cancelled;
      throw AuthFailure('Google sign-in did not finish${e.description == null ? '' : ': ${e.description}'}');
    }
  }

  @override
  Future<AuthStep> signInWithApple() async {
    // iPhone, iPad and Mac have Apple's own sheet; everywhere else Apple signs in on its web page.
    final native = !kIsWeb && (Platform.isIOS || Platform.isMacOS);
    if (!native) {
      final ok = await _auth.signInWithOAuth(
        sb.OAuthProvider.apple,
        redirectTo: BackendConfig.callbackUrl,
        authScreenLaunchMode: sb.LaunchMode.externalApplication,
      );
      if (!ok) throw const AuthFailure('Could not open the browser for Apple.');
      return AuthStep.browser;
    }
    final raw = _auth.generateRawNonce();
    try {
      final c = await SignInWithApple.getAppleIDCredential(
        scopes: const [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: sha256.convert(utf8.encode(raw)).toString(),
      );
      final idToken = c.identityToken;
      if (idToken == null) throw const AuthFailure('Apple did not hand over a sign-in token. Try again.');
      await _auth.signInWithIdToken(provider: sb.OAuthProvider.apple, idToken: idToken, nonce: raw).timeout(const Duration(seconds: 20));
      // Apple gives the name only the very first time: keep it.
      final name = [c.givenName, c.familyName].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
      if (name.isNotEmpty && (current?.name ?? '').isEmpty) await rename(name);
      return AuthStep.done;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return AuthStep.cancelled;
      throw AuthFailure('Apple sign-in did not finish: ${e.message}');
    }
  }

  @override
  Future<void> resendConfirmation(String email) =>
      _auth.resend(type: sb.OtpType.signup, email: email, emailRedirectTo: BackendConfig.callbackUrl).timeout(const Duration(seconds: 20));

  @override
  Future<void> verifyEmailCode({required String email, required String code}) async {
    await _auth.verifyOTP(type: sb.OtpType.email, email: email, token: code).timeout(const Duration(seconds: 20));
  }

  @override
  Future<void> sendPasswordReset(String email) =>
      _auth.resetPasswordForEmail(email, redirectTo: BackendConfig.callbackUrl).timeout(const Duration(seconds: 20));

  @override
  Future<void> resetWithCode({required String email, required String code, required String password}) async {
    await _auth.verifyOTP(type: sb.OtpType.recovery, email: email, token: code).timeout(const Duration(seconds: 20));
    await changePassword(password);
  }

  @override
  Future<void> changePassword(String password) async {
    await _auth.updateUser(sb.UserAttributes(password: password)).timeout(const Duration(seconds: 20));
  }

  @override
  Future<void> rename(String name) async {
    final u = _auth.currentUser;
    if (u == null) return;
    await _auth.updateUser(sb.UserAttributes(data: {'display_name': name})).timeout(const Duration(seconds: 20));
    await sb.Supabase.instance.client.from('profiles').upsert({'id': u.id, 'display_name': name}).timeout(const Duration(seconds: 20));
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut().timeout(const Duration(seconds: 10));
    } catch (_) {
      // Offline: forget the session on this phone anyway.
      await _auth.signOut(scope: sb.SignOutScope.local);
    }
    if (_googleReady) unawaited(GoogleSignIn.instance.signOut().catchError((Object _) {}));
  }

  @override
  Future<void> deleteAccount() async {
    await sb.Supabase.instance.client.rpc('delete_own_account').timeout(const Duration(seconds: 20));
    await _auth.signOut(scope: sb.SignOutScope.local);
    if (_googleReady) unawaited(GoogleSignIn.instance.disconnect().catchError((Object _) {}));
  }
}
