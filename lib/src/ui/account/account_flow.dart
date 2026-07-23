import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/trail_summary.dart';
import '../../providers.dart';
import 'create_account_screen.dart';
import 'enter_code_screen.dart';
import 'keep_which_trail_screen.dart';
import 'set_new_password_screen.dart';
import 'sign_in_screen.dart';

/// Which screen [AccountFlow] opens on.
enum AccountEntryPoint { createAccount, signIn }

/// Hosts every Phase 4b account-upgrade screen (Create account, Sign in,
/// Enter code, Set a new password, Keep which trail) on its OWN nested
/// [Navigator], the same pattern `OnboardingFlow` uses and for the same
/// reason: pushing these as a single route (wherever the caller pushes
/// [AccountFlow] itself - Profile's root navigator, or onboarding's own
/// nested navigator) means closing the whole multi-screen flow is always
/// exactly one pop of that one route, regardless of how many screens deep
/// the user navigated (Create account -> Enter code -> ... ), rather than
/// each screen needing to pop itself off some shared root stack N times.
///
/// [start] picks the initial screen: Profile's "Create" action opens at
/// [AccountEntryPoint.createAccount]; onboarding's "I already have an
/// account" opens at [AccountEntryPoint.signIn]. [onComplete], when given,
/// runs right before the flow closes on a *successful* sign-in/create
/// (never on a plain close-via-X) - onboarding uses this to mark itself
/// complete and hand off to [AppShell] instead of merely popping back to
/// the welcome screen.
class AccountFlow extends ConsumerStatefulWidget {
  const AccountFlow({super.key, required this.start, this.onComplete});

  final AccountEntryPoint start;
  final VoidCallback? onComplete;

  @override
  ConsumerState<AccountFlow> createState() => _AccountFlowState();
}

class _AccountFlowState extends ConsumerState<AccountFlow> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  static const _createRoute = '/create';
  static const _signInRoute = '/sign-in';
  static const _enterCodeRoute = '/enter-code';
  static const _setNewPasswordRoute = '/set-new-password';
  static const _keepWhichTrailRoute = '/keep-which-trail';

  /// Closes the whole flow: pops whichever ancestor [Navigator] pushed this
  /// [AccountFlow] widget in the first place (Profile's root navigator, or
  /// onboarding's own nested one) - `context` here is [AccountFlow]'s own
  /// position in the tree, an ANCESTOR of the inner [Navigator] this state
  /// builds below, so `Navigator.of(context)` resolves to that outer
  /// navigator rather than the inner one, regardless of which launched it.
  void _closeFlow() {
    final navigator = Navigator.maybeOf(context);
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    }
  }

  /// Runs after a successful sign-in/create-account completes: refreshes
  /// the Profile row's [accountStateProvider], runs the caller's own
  /// [AccountFlow.onComplete] hook (onboarding's completion), then closes
  /// the flow (a no-op if [AccountFlow.onComplete] already unmounted this
  /// widget by swapping the whole subtree, e.g. onboarding's own gate).
  void _completeAndClose() {
    ref.invalidate(accountStateProvider);
    widget.onComplete?.call();
    if (!mounted) return;
    _closeFlow();
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navigatorKey,
      initialRoute: widget.start == AccountEntryPoint.createAccount
          ? _createRoute
          : _signInRoute,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case _signInRoute:
            final args = settings.arguments as _SignInArgs?;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => SignInScreen(
                onClose: _closeFlow,
                initialEmail: args?.prefillEmail,
                onSignInComplete: _completeAndClose,
                onNeedsTrailChoice: (local, remote) {
                  _navigatorKey.currentState!.pushNamed(
                    _keepWhichTrailRoute,
                    arguments: _KeepWhichTrailArgs(local: local, remote: remote),
                  );
                },
                onForgotPassword: (email) {
                  _navigatorKey.currentState!.pushNamed(
                    _enterCodeRoute,
                    arguments: _EnterCodeArgs(
                      purpose: AccountCodePurpose.passwordReset,
                      email: email,
                    ),
                  );
                },
                onCreateAccount: () =>
                    _navigatorKey.currentState!.pushNamed(_createRoute),
              ),
            );

          case _enterCodeRoute:
            final args = settings.arguments! as _EnterCodeArgs;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => EnterCodeScreen(
                onClose: _closeFlow,
                purpose: args.purpose,
                email: args.email,
                password: args.password,
                onVerified: args.purpose == AccountCodePurpose.verifyEmail
                    ? _completeAndClose
                    : () => _navigatorKey.currentState!.pushNamed(
                          _setNewPasswordRoute,
                          arguments: _SetNewPasswordArgs(email: args.email),
                        ),
              ),
            );

          case _setNewPasswordRoute:
            final args = settings.arguments! as _SetNewPasswordArgs;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => SetNewPasswordScreen(
                onClose: _closeFlow,
                email: args.email,
                onSaved: _completeAndClose,
              ),
            );

          case _keepWhichTrailRoute:
            final args = settings.arguments! as _KeepWhichTrailArgs;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => KeepWhichTrailScreen(
                onClose: _closeFlow,
                local: args.local,
                remote: args.remote,
                onDone: _completeAndClose,
              ),
            );

          case _createRoute:
          default:
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => CreateAccountScreen(
                onClose: _closeFlow,
                onCreated: (email, password) {
                  _navigatorKey.currentState!.pushNamed(
                    _enterCodeRoute,
                    arguments: _EnterCodeArgs(
                      purpose: AccountCodePurpose.verifyEmail,
                      email: email,
                      password: password,
                    ),
                  );
                },
                onSignInInstead: (email) => _navigatorKey.currentState!.pushNamed(
                  _signInRoute,
                  arguments: _SignInArgs(prefillEmail: email),
                ),
              ),
            );
        }
      },
    );
  }
}

class _SignInArgs {
  final String? prefillEmail;
  const _SignInArgs({this.prefillEmail});
}

class _EnterCodeArgs {
  final AccountCodePurpose purpose;
  final String email;
  final String? password;
  const _EnterCodeArgs({required this.purpose, required this.email, this.password});
}

class _SetNewPasswordArgs {
  final String email;
  const _SetNewPasswordArgs({required this.email});
}

class _KeepWhichTrailArgs {
  final TrailSummary local;
  final TrailSummary remote;
  const _KeepWhichTrailArgs({required this.local, required this.remote});
}
