---
type: guide
project: "[[README|Memory Card]]"
created: 2026-10-27
updated: 2026-10-27
status: active
tags:
  - project/memory-card
  - document/guide
---

# Accounts: setup and how they work

Accounts are **optional**. The app works fully offline without one; signing in puts your name on the membership card
and is the base for sync later. Decks, progress, pictures, videos and recordings stay on the phone.

## What is already done

| Piece | State |
|---|---|
| Supabase project `memory-card` (eu-central-1, ref `uuhcuibwqqhzmiakqbmv`) | Created 2026-10-27, $10/month |
| `public.profiles` table (name, avatar) with row-level security: each account reads and edits only its own row | Done (migration `profiles_and_account_deletion`) |
| A profile row made for every new account (trigger `on_auth_user_created`) | Done |
| `delete_own_account()`: "Delete my account" in the app removes only the caller | Done (the Supabase advisor flags it as a callable SECURITY DEFINER function: that is on purpose) |
| URL and publishable key in the app (`app/lib/services/backend_config.dart`) | Done. The publishable key is meant to ship in apps |
| Email and password: sign in, create an account, confirm by link or code, forgot password, change password, sign out, delete | Works now |
| Google sign-in (Android account picker, then Supabase) | Code done; **needs the Google Cloud steps below** |
| Sign in with Apple (Apple's sheet on iPhone, Apple's web page on Android) | Code done; **needs the Apple steps below** |

Until Google or Apple is switched on in Supabase, their buttons say **SOON** and explain it when tapped. The app asks
the server which ways of signing in are on (`/auth/v1/settings`) each launch, so switching one on needs no new build
(Google also needs its client ID in the build, see below).

## 1 · Supabase dashboard (5 minutes, do these first)

Open https://supabase.com/dashboard/project/uuhcuibwqqhzmiakqbmv

1. **Authentication › URL Configuration › Redirect URLs:** add `com.memorycard.app://login-callback`.
   This is where Apple's web sign-in and the links in account emails come back to the app.
2. **Emails can only reach your own team until SMTP is set.** Supabase's built-in mailer only delivers to the
   addresses of your organisation's members (and only a few an hour). Pick one:
   - **For testing:** Authentication › Sign In / Providers › Email › turn **Confirm email** off. New accounts can
     sign in straight away; "Forgot password" still needs mail.
   - **For real users:** Authentication › Emails › SMTP Settings: add a sender (Resend, Postmark, Brevo, SES…).
3. **Codes in the emails (recommended):** Authentication › Emails › Templates. In *Confirm signup* and
   *Reset Password*, add a line with `{{ .Token }}`, for example: `Or type this code in the app: {{ .Token }}`.
   The app accepts either the link or the 6-digit code; the code works even when the email is read on a computer.

## 2 · Google sign-in

You need a Google Cloud project (free): https://console.cloud.google.com

1. **APIs & Services › OAuth consent screen:** External, app name "Memory Card", your support email, scopes
   `email`, `profile`, `openid`. Add yourself as a test user while it is in Testing.
2. **Credentials › Create credentials › OAuth client ID › Web application** named "Memory Card (Supabase)".
   Authorized redirect URI: `https://uuhcuibwqqhzmiakqbmv.supabase.co/auth/v1/callback`.
   Copy its **Client ID** and **Client secret**.
3. **Credentials › Create credentials › OAuth client ID › Android:** package `com.memorycard.app`, SHA-1 of the key
   the APK is signed with. Release APKs are signed with this machine's debug key:
   `E6:08:C5:F4:4E:38:19:80:4F:D6:24:7F:B5:42:C7:6B:D7:BC:14:F9`
   (check: `keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android`).
   Nothing to copy from this one: it lets Android's account picker hand tokens to this app.
4. **Supabase › Authentication › Sign In / Providers › Google:** turn it on, paste the *Web* client ID and secret.
   Under "Authorized Client IDs" also paste the Web client ID.
5. **Build the app with the Web client ID:**

   ```bash
   flutter build apk --release --dart-define=GOOGLE_WEB_CLIENT_ID=<web client id>.apps.googleusercontent.com
   ```

   (or put it as the `defaultValue` of `googleWebClientId` in `app/lib/services/backend_config.dart`; client IDs are
   not secrets). For an iPhone build also make an *iOS* client and pass `GOOGLE_IOS_CLIENT_ID`, add its reversed ID
   as a URL scheme in `ios/Runner/Info.plist`, and turn on "Skip nonce check" in Supabase's Google provider.

## 3 · Sign in with Apple

This needs a paid Apple Developer account ($99/year): https://developer.apple.com/account

1. **Identifiers › App IDs:** the app's bundle ID (for an iPhone build) with *Sign in with Apple* checked.
2. **Identifiers › Services IDs:** e.g. `com.memorycard.app.signin`, *Sign in with Apple* checked, configured with
   domain `uuhcuibwqqhzmiakqbmv.supabase.co` and return URL
   `https://uuhcuibwqqhzmiakqbmv.supabase.co/auth/v1/callback`. Android uses this web flow.
3. **Keys:** a key with *Sign in with Apple*; download the `.p8` once, note the Key ID and your Team ID.
4. **Supabase › Authentication › Sign In / Providers › Apple:** turn it on; Client IDs = the Services ID (and the
   bundle ID for iPhone); generate the secret from the `.p8`, Team ID and Key ID (Supabase links its generator).
   Apple's secret expires every 6 months: put a reminder in your calendar.
5. iPhone builds: in Xcode, Runner › Signing & Capabilities › **+ Sign in with Apple** (it links
   `ios/Runner/Runner.entitlements`). Apple only shares a name the first time; the app saves it to the profile then.

## How the app uses it

- `lib/services/account.dart`: `Account.i` (the signed-in `user`, sign-in methods, friendly errors, the card-name
  link: an empty card name takes the account's name, a nameless account takes the card's), `SupabaseAuth` (the real
  server), `AuthBackend` (what tests fake).
- `lib/features/account/sign_in_sheet.dart`: the sign-in sheet (Apple, Google, email, create, check your email,
  forgot / reset password, finish in the browser) and the account sheet (change password, sign out, delete).
- Entry points: the Account tab's three badges (Google, Memory Card account, Apple) and "Have an account? Sign in";
  onboarding's "Your card" step ("Sign in or create one", Continue skips it).
- Sessions persist on the phone and refresh by themselves. Signing out or deleting the account never erases anything
  on the phone.
- Deep links: only `com.memorycard.app://` links are read as sign-in callbacks, so widget taps (`memorycard://…`)
  keep working with Flutter's own deep linking off.
