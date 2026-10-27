import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/account.dart';
import '../../ui/fx.dart';
import '../../ui/icons.dart';
import '../../ui/motion.dart';
import '../../ui/overlays.dart';
import '../../ui/shapes.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

/// Opens the sign-in sheet. [create] starts on "Create an account"; [start] ('google' · 'apple') begins that
/// sign-in right away (the Account tab's badges). Returns true when someone is signed in at the end.
Future<bool> showSignInSheet(BuildContext context, {bool create = false, String? start}) async {
  final r = await showMcSheet<bool>(context, builder: (_) => SignInSheet(create: create, start: start));
  return r ?? Account.i.user.value != null;
}

enum _Mode { signIn, create, confirm, forgot, reset, newPassword, browser }

class SignInSheet extends StatefulWidget {
  const SignInSheet({super.key, this.create = false, this.start});
  final bool create;
  final String? start;

  @override
  State<SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<SignInSheet> {
  late _Mode _mode = widget.create ? _Mode.create : _Mode.signIn;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _show = false;
  String? _busy;
  String? _error;
  String? _info;
  AuthProviders _providers = AuthProviders.unknown;
  StreamSubscription<void>? _recovery;

  @override
  void initState() {
    super.initState();
    Account.i.user.addListener(_userChanged);
    _recovery = Account.i.recovery.listen((_) {
      if (mounted) _go(_Mode.newPassword);
    });
    Account.i.providers().then((p) {
      if (mounted) setState(() => _providers = p);
    });
    final s = widget.start;
    if (s != null) WidgetsBinding.instance.addPostFrameCallback((_) => _provider(s));
  }

  @override
  void dispose() {
    Account.i.user.removeListener(_userChanged);
    _recovery?.cancel();
    for (final c in [_name, _email, _password, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Signed in (here, in the browser, or from a link in an email): the sheet's work is done.
  void _userChanged() {
    final u = Account.i.user.value;
    if (u == null || !mounted || _mode == _Mode.newPassword) return;
    Fx.i.stamp();
    Toaster.i.show(u.name.isEmpty ? 'Signed in' : 'Signed in as ${u.name}');
    Navigator.of(context).pop(true);
  }

  void _go(_Mode m) {
    FocusScope.of(context).unfocus();
    setState(() {
      _mode = m;
      _error = null;
      _info = null;
      _code.clear();
      if (m == _Mode.newPassword || m == _Mode.reset) _password.clear();
    });
  }

  Future<void> _act(String what, Future<void> Function() f) async {
    if (_busy != null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = what;
      _error = null;
      _info = null;
    });
    try {
      await f();
    } on AuthFailure catch (e) {
      Fx.i.warn();
      if (mounted) {
        setState(() {
          _error = e.message;
          if (e.needsConfirm) _mode = _Mode.confirm;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  bool _check({bool name = false, bool password = true}) {
    final err = (name && _name.text.trim().isEmpty ? 'Your name' : null) ??
        Account.checkEmail(_email.text) ??
        (password ? Account.checkPassword(_password.text) : null);
    if (err != null) {
      Fx.i.warn();
      setState(() => _error = err);
      return false;
    }
    return true;
  }

  // ---------------------------------------------------------------- actions

  Future<void> _provider(String id) async {
    final p = await Account.i.providers();
    if (!mounted) return;
    final on = id == 'google' ? p.google : p.apple;
    if (!on) {
      Fx.i.warn();
      setState(() => _error = '${id == 'google' ? 'Google' : 'Apple'} sign-in is not switched on for Memory Card yet. '
          'Use your email for now: you can link it later.');
      return;
    }
    await _act(id, () async {
      final step = id == 'google' ? await Account.i.signInWithGoogle() : await Account.i.signInWithApple();
      if (step == AuthStep.browser && mounted) setState(() => _mode = _Mode.browser);
    });
  }

  Future<void> _signIn() async {
    if (!_check()) return;
    await _act('email', () => Account.i.signIn(email: _email.text, password: _password.text));
  }

  Future<void> _create() async {
    if (!_check(name: true)) return;
    await _act('email', () async {
      final step = await Account.i.signUp(name: _name.text, email: _email.text, password: _password.text);
      if (step == AuthStep.confirmEmail && mounted) _go(_Mode.confirm);
    });
  }

  Future<void> _confirmed() async {
    final code = _code.text.trim();
    if (code.isNotEmpty) {
      await _act('code', () => Account.i.verifyEmailCode(email: _email.text, code: code));
      return;
    }
    // Confirmed by the link (in any browser): the password works now.
    if (_password.text.isEmpty) {
      _go(_Mode.signIn);
      setState(() => _info = 'Confirmed? Sign in with your password.');
      return;
    }
    await _act('email', () => Account.i.signIn(email: _email.text, password: _password.text));
  }

  Future<void> _resend() async {
    await _act('resend', () async {
      await Account.i.resendConfirmation(_email.text);
      if (mounted) setState(() => _info = 'Sent again. It can take a minute; check the spam folder too.');
    });
  }

  Future<void> _sendReset() async {
    if (!_check(password: false)) return;
    await _act('reset', () async {
      await Account.i.sendPasswordReset(_email.text);
      if (mounted) {
        _go(_Mode.reset);
        setState(() => _info = 'Sent to ${_email.text.trim()}.');
      }
    });
  }

  Future<void> _resetWithCode() async {
    final err = (_code.text.trim().length < 6 ? 'The 6-digit code from the email' : null) ?? Account.checkPassword(_password.text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    await _act('reset', () => Account.i.resetWithCode(email: _email.text, code: _code.text, password: _password.text));
  }

  Future<void> _setNewPassword() async {
    final err = Account.checkPassword(_password.text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    await _act('save', () async {
      await Account.i.changePassword(_password.text);
      if (!mounted) return;
      Fx.i.stamp();
      Toaster.i.show('New password saved');
      Navigator.of(context).pop(true);
    });
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final mq = MediaQuery.of(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 2, 20, 20 + mq.padding.bottom + mq.viewInsets.bottom),
      children: [
        AnimatedSwitcher(
          duration: Duration(milliseconds: MotionPrefs.reducedOf(context) ? 0 : 240),
          switchInCurve: McCurves.out,
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a), child: c),
          ),
          child: KeyedSubtree(key: ValueKey(_mode), child: _page(mc)),
        ),
      ],
    );
  }

  Widget _page(Mc mc) => switch (_mode) {
        _Mode.signIn || _Mode.create => _front(mc),
        _Mode.confirm => _confirm(mc),
        _Mode.forgot => _forgot(mc),
        _Mode.reset => _reset(mc),
        _Mode.newPassword => _newPassword(mc),
        _Mode.browser => _browser(mc),
      };

  Widget _title(Mc mc, String title, String sub) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: T.d(32, color: mc.ink, height: 1.05)),
        const SizedBox(height: 6),
        Text(sub, style: T.t(15, w: FontWeight.w500, color: mc.muted, height: 1.35)),
        const SizedBox(height: 18),
      ]);

  Widget _notes(Mc mc) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Semantics(liveRegion: true, child: Text(_error!, style: T.t(15, w: FontWeight.w700, color: Mc.red, height: 1.3))),
          ),
        if (_info != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Semantics(liveRegion: true, child: Text(_info!, style: T.t(15, w: FontWeight.w600, color: mc.ink, height: 1.3))),
          ),
      ]);

  Widget _link(Mc mc, String text, VoidCallback onTap, {bool strong = false}) => Pressable(
        onTap: _busy == null ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(text,
              textAlign: TextAlign.center,
              style: T.t(15.5, w: strong ? FontWeight.w800 : FontWeight.w700, color: strong ? mc.ink : mc.muted)
                  .copyWith(decoration: strong ? TextDecoration.underline : null)),
        ),
      );

  Widget _button(String label, String id, VoidCallback onTap) => InkButton(
        _busy == id ? 'One moment…' : label,
        height: 54,
        size: 23,
        enabled: _busy == null,
        onTap: onTap,
      );

  Widget _passwordField(String hint, {bool newOne = false, VoidCallback? onDone}) => McField(
        controller: _password,
        hint: hint,
        obscure: !_show,
        autofillHints: [newOne ? AutofillHints.newPassword : AutofillHints.password],
        textInputAction: onDone == null ? TextInputAction.next : TextInputAction.done,
        onSubmitted: onDone == null ? null : (_) => onDone(),
        suffix: IconButton(
          tooltip: _show ? 'Hide the password' : 'Show the password',
          onPressed: () => setState(() => _show = !_show),
          icon: Opacity(
            opacity: _show ? 1 : 0.5,
            child: McIcon(McIcons.eye, size: const Size(22, 22), color: Mc.of(context).ink),
          ),
        ),
      );

  Widget _emailField({bool autofocus = false}) => McField(
        controller: _email,
        hint: 'Email address',
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        textInputAction: TextInputAction.next,
        autofocus: autofocus,
      );

  /// Sign in / create: Apple and Google first, then email and password.
  Widget _front(Mc mc) {
    final create = _mode == _Mode.create;
    return AutofillGroup(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _title(
          mc,
          create ? 'Create your account' : 'Sign in',
          'Optional. Your name goes on your membership card, and everything keeps working offline.',
        ),
        _ProviderButton(
          label: 'Continue with Apple',
          icon: McIcons.apple,
          dark: true,
          busy: _busy == 'apple',
          off: !_providers.apple,
          onTap: () => _provider('apple'),
        ),
        const SizedBox(height: 10),
        _ProviderButton(
          label: 'Continue with Google',
          icon: McIcons.google,
          dark: false,
          busy: _busy == 'google',
          off: !_providers.google,
          onTap: () => _provider('google'),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: Container(height: 2, color: mc.line)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('or with email', style: T.t(14, w: FontWeight.w700, color: mc.muted)),
          ),
          Expanded(child: Container(height: 2, color: mc.line)),
        ]),
        const SizedBox(height: 16),
        if (create) ...[
          McField(
            controller: _name,
            hint: 'Your name',
            display: true,
            size: 22,
            autofillHints: const [AutofillHints.name],
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
        ],
        _emailField(),
        const SizedBox(height: 10),
        _passwordField(create ? 'A password (8 or more characters)' : 'Password', newOne: create, onDone: create ? _create : _signIn),
        _notes(mc),
        const SizedBox(height: 14),
        _button(create ? 'Create my account' : 'Sign in', 'email', create ? _create : _signIn),
        if (!create) _link(mc, 'Forgot your password?', () => _go(_Mode.forgot)),
        _link(mc, create ? 'Have an account? Sign in' : 'New here? Create an account', () => _go(create ? _Mode.signIn : _Mode.create),
            strong: true),
        if (create)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Your library stays on this phone. The account keeps your name and email, nothing else, and you can delete it any time.',
                textAlign: TextAlign.center, style: T.t(13, w: FontWeight.w500, color: mc.muted, height: 1.35)),
          ),
      ]),
    );
  }

  Widget _seal(Mc mc, String icon, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Center(child: WaxSeal(size: 78, color: color, child: McIcon(icon, size: const Size(30, 30), color: Mc.graphite))),
      );

  Widget _codeField(String hint) => McField(
        controller: _code,
        hint: hint,
        onChanged: (_) => setState(() {}), // the button says what it will do with the code
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        size: 22,
        textInputAction: TextInputAction.next,
      );

  Widget _confirm(Mc mc) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _seal(mc, McIcons.mail, Mc.peach),
      _title(
        mc,
        'Check your email',
        'We sent a link to ${_email.text.trim()}. Open it to confirm the address, then come back here. '
            'If the email has a code, you can type it instead.',
      ),
      _codeField('6-digit code (optional)'),
      _notes(mc),
      const SizedBox(height: 14),
      _button(_code.text.trim().isEmpty ? 'I confirmed it · sign me in' : 'Confirm the code', 'email', _confirmed),
      _link(mc, _busy == 'resend' ? 'Sending…' : 'Send the email again', _resend),
      _link(mc, 'Use a different email', () => _go(_Mode.create)),
    ]);
  }

  Widget _forgot(Mc mc) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _title(mc, 'Forgot your password?', 'We will email you a link (and a code) to set a new one.'),
      _emailField(autofocus: true),
      _notes(mc),
      const SizedBox(height: 14),
      _button('Send the email', 'reset', _sendReset),
      _link(mc, 'Back to sign in', () => _go(_Mode.signIn)),
    ]);
  }

  Widget _reset(Mc mc) {
    return AutofillGroup(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _seal(mc, McIcons.mail, Mc.peach),
        _title(mc, 'Set a new password', 'Open the link in the email on this phone, or type the code from it here.'),
        _codeField('6-digit code'),
        const SizedBox(height: 10),
        _passwordField('New password (8 or more characters)', newOne: true, onDone: _resetWithCode),
        _notes(mc),
        const SizedBox(height: 14),
        _button('Save the new password', 'reset', _resetWithCode),
        _link(mc, 'Send the email again', _sendReset),
        _link(mc, 'Back to sign in', () => _go(_Mode.signIn)),
      ]),
    );
  }

  Widget _newPassword(Mc mc) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _title(mc, 'Set a new password', 'The link worked. Choose the password you will sign in with from now on.'),
      _passwordField('New password (8 or more characters)', newOne: true, onDone: _setNewPassword),
      _notes(mc),
      const SizedBox(height: 14),
      _button('Save the new password', 'save', _setNewPassword),
    ]);
  }

  Widget _browser(Mc mc) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 10),
      Center(child: SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3.5, color: mc.ink))),
      const SizedBox(height: 18),
      _title(mc, 'Finish in your browser', 'Sign in with Apple there. When it is done you come straight back here.'),
      _notes(mc),
      SoftButton('Back', onTap: () => _go(_Mode.signIn)),
    ]);
  }
}

/// "Continue with Apple / Google": a full-width button with the brand's mark.
class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.icon,
    required this.dark,
    required this.busy,
    required this.off,
    required this.onTap,
  });

  final String label;
  final String icon;
  final bool dark;
  final bool busy;

  /// Not switched on yet: it still answers, and says so.
  final bool off;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final bg = dark ? mc.ink : mc.soft;
    final fg = dark ? mc.canvas : mc.ink;
    return Pressable(
      onTap: busy ? null : onTap,
      haptic: true,
      label: label,
      child: Opacity(
        opacity: off ? 0.55 : 1,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: mc.e1,
            border: dark ? null : Border.all(color: mc.line, width: 2),
          ),
          child: Row(children: [
            SizedBox(
              width: 40,
              child: Align(
                alignment: Alignment.centerLeft,
                child: McIcon(icon, size: const Size(22, 24), color: icon == McIcons.google ? null : fg),
              ),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(busy ? 'One moment…' : label, maxLines: 1, style: T.d(21, color: fg)),
              ),
            ),
            SizedBox(
              width: 40,
              child: off
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text('SOON', maxLines: 1, style: T.caps(10, color: fg.withValues(alpha: 0.8))),
                    )
                  : null,
            ),
          ]),
        ),
      ),
    );
  }
}

/// The signed-in account: who, how, and the things you can do with it (password, sign out, delete).
Future<void> showAccountSheet(BuildContext context) => showMcSheet<void>(context, expand: false, builder: (_) => const AccountSheet());

class AccountSheet extends StatefulWidget {
  const AccountSheet({super.key});

  @override
  State<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<AccountSheet> {
  final _password = TextEditingController();
  bool _changing = false;
  bool _show = false;
  String? _busy;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _act(String what, Future<void> Function() f) async {
    if (_busy != null) return;
    setState(() {
      _busy = what;
      _error = null;
    });
    try {
      await f();
    } on AuthFailure catch (e) {
      Fx.i.warn();
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _savePassword() async {
    final err = Account.checkPassword(_password.text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    await _act('password', () async {
      await Account.i.changePassword(_password.text);
      if (!mounted) return;
      Toaster.i.show('New password saved');
      setState(() {
        _changing = false;
        _password.clear();
      });
    });
  }

  Future<void> _signOut() async {
    await _act('out', () async {
      await Account.i.signOut();
      if (!mounted) return;
      Navigator.pop(context);
      Toaster.i.show('Signed out. Everything on this phone stays.');
    });
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Delete your account?',
      message: 'Your account and its name leave our server for good. Your decks and progress on this phone stay, and you can '
          'make a new account later.',
      yes: 'Delete it',
      no: 'Keep it',
    );
    if (!ok || !mounted) return;
    await _act('delete', () async {
      await Account.i.deleteAccount();
      if (!mounted) return;
      Navigator.pop(context);
      Toaster.i.show('Account deleted. Your library is still here.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final mc = Mc.of(context);
    final mq = MediaQuery.of(context);
    return ValueListenableBuilder<AccountUser?>(
      valueListenable: Account.i.user,
      builder: (context, u, _) {
        if (u == null) return const SizedBox(height: 120);
        final initial = (u.name.isNotEmpty ? u.name : u.email).characters.first.toUpperCase();
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + mq.padding.bottom + mq.viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              WaxSeal(size: 64, color: Mc.blue, child: Text(initial, style: T.d(28, color: Mc.graphite))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.name.isEmpty ? 'Your account' : u.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.d(28, color: mc.ink)),
                  Text(u.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.t(15, w: FontWeight.w600, color: mc.muted)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: mc.soft, borderRadius: BorderRadius.circular(14)),
              child: Text('Signed in with ${u.providerName}. Your decks and progress live on this phone.',
                  style: T.t(14.5, w: FontWeight.w600, color: mc.ink, height: 1.3)),
            ),
            const SizedBox(height: 14),
            if (u.provider == 'email') ...[
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: McCurves.out,
                alignment: Alignment.topCenter,
                child: _changing
                    ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        McField(
                          controller: _password,
                          hint: 'New password (8 or more characters)',
                          obscure: !_show,
                          autofocus: true,
                          autofillHints: const [AutofillHints.newPassword],
                          onSubmitted: (_) => _savePassword(),
                          suffix: IconButton(
                            tooltip: _show ? 'Hide the password' : 'Show the password',
                            onPressed: () => setState(() => _show = !_show),
                            icon: Opacity(opacity: _show ? 1 : 0.5, child: McIcon(McIcons.eye, size: const Size(22, 22), color: mc.ink)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        InkButton(_busy == 'password' ? 'One moment…' : 'Save the new password', height: 52, size: 22, onTap: _savePassword),
                        const SizedBox(height: 10),
                      ])
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SoftButton('Change password', onTap: () => setState(() => _changing = true)),
                      ),
              ),
            ],
            SoftButton(_busy == 'out' ? 'Signing out…' : 'Sign out', onTap: _signOut),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, style: T.t(15, w: FontWeight.w700, color: Mc.red, height: 1.3)),
              ),
            Pressable(
              onTap: _busy == null ? _delete : null,
              child: Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 4),
                child: Text(_busy == 'delete' ? 'Deleting…' : 'Delete my account',
                    textAlign: TextAlign.center, style: T.t(15, w: FontWeight.w700, color: Mc.red)),
              ),
            ),
          ]),
        );
      },
    );
  }
}
