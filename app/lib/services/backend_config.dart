/// Where accounts live (Supabase project "memory-card", eu-central-1) and the IDs Google and Apple sign-in
/// need. Every value can be overridden at build time:
///
///   flutter build apk --dart-define=GOOGLE_WEB_CLIENT_ID=1234-abc.apps.googleusercontent.com
///
/// The publishable key is meant to ship inside apps: it only allows what the database's row-level security
/// allows (each account reads and edits its own profile, nothing else). Setup steps: docs/accounts.md.
class BackendConfig {
  const BackendConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://uuhcuibwqqhzmiakqbmv.supabase.co');

  static const publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: 'sb_publishable_EgW6E6ZimGvzQiarebNcOA_CkA0kXHL');

  /// The OAuth "Web application" client from Google Cloud: Supabase checks Google's ID tokens against it,
  /// and Android's account picker asks for tokens addressed to it. Empty = Google sign-in not set up yet.
  static const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  /// The OAuth "iOS" client from Google Cloud (iPhone builds only).
  static const googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  /// Where a browser sign-in (Apple on Android) and the links in account emails come back to the app.
  /// Must be listed in Supabase › Authentication › URL Configuration › Redirect URLs.
  static const callbackScheme = 'com.memorycard.app';
  static const callbackUrl = '$callbackScheme://login-callback';

  static bool get configured => supabaseUrl.isNotEmpty && publishableKey.isNotEmpty;
}
