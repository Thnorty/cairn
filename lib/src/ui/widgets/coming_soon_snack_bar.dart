import 'package:flutter/material.dart' show ScaffoldMessenger, SnackBar, Text;
import 'package:flutter/widgets.dart' show BuildContext;

/// Shared snackbar-presentation helper for the handful of affordances across
/// this app that have no real destination yet (Premium's "Start trial",
/// Profile's "Create account", the onboarding flow's "Sign in"/"Learn more"
/// links) plus a couple of one-off messages with the exact same shape (Home's
/// safety-net message for an otherwise-unreachable proof rejection, New
/// Habit's validation-error surface) - every one of these used to hand-roll
/// the identical `ScaffoldMessenger.of(context).showSnackBar(SnackBar(
/// content: Text(message)))` call independently. Factored out here so there
/// is one place that decides how any of these plain, no-frills messages are
/// presented; every call site still supplies its own message text (an ARB
/// string, or - for the two non-"coming soon" call sites - its own existing
/// plain-string content), unchanged.
extension ComingSoonSnackBar on BuildContext {
  /// Shows [message] in a plain [SnackBar] via this context's nearest
  /// [ScaffoldMessenger]: no custom duration, action, or styling, matching
  /// every call site this replaces.
  void showComingSoonSnackBar(String message) {
    ScaffoldMessenger.of(this).showSnackBar(SnackBar(content: Text(message)));
  }
}
