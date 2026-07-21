import 'package:flutter/material.dart' show ScaffoldMessenger, SnackBar, Text;
import 'package:flutter/widgets.dart' show BuildContext;

/// Shared helper for presenting a plain, no-frills text [SnackBar] - the one
/// place that decides how these simple transient messages look across the
/// app. Every call site that used to hand-roll the identical
/// `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(...)))`
/// now routes through here, each still supplying its own message text: the
/// several "no real destination yet" affordances (Premium's "Start trial",
/// Profile's "Create account", the onboarding "Sign in"/"Learn more" links),
/// plus a couple of one-off messages with the exact same shape (Home's
/// safety-net message for an otherwise-unreachable proof rejection, New
/// Habit's validation-error surface). The name is deliberately neutral: this
/// is just "show a message in a snackbar", not specific to any one intent.
extension MessageSnackBar on BuildContext {
  /// Shows [message] in a plain [SnackBar] via this context's nearest
  /// [ScaffoldMessenger]: no custom duration, action, or styling, matching
  /// every call site this replaces.
  void showMessageSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(SnackBar(content: Text(message)));
  }
}
