import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:virtual_wardrobe/utils/user_facing_exception.dart';

/// Converts an exception into a short, user-safe message.
///
/// Raw exception text can leak internals (DB columns, stack traces, provider
/// errors) and reads as "broken" to users, so it is never surfaced. A
/// [UserFacingException] is passed through as-is because its message was
/// already written for the user. Recognised connectivity failures get a
/// consistent network message; everything else returns [fallback] — pass a
/// context-specific line such as "Couldn't save your item.".
///
/// The real error is always logged (debug builds) so developers keep the detail.
String friendlyError(
  Object error, {
  required String fallback,
  StackTrace? stackTrace,
}) {
  if (kDebugMode) {
    debugPrint('friendlyError: $error'
        '${stackTrace != null ? '\n$stackTrace' : ''}');
  }

  if (error is UserFacingException) return error.message;

  if (error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException) {
    return 'No internet connection. Please check your network and try again.';
  }

  return fallback;
}

/// Shows [friendlyError] in a SnackBar. Safe to call after an await: it no-ops
/// if no ScaffoldMessenger is available (e.g. the widget was disposed).
void showErrorSnackBar(
  BuildContext context,
  Object error, {
  required String fallback,
  StackTrace? stackTrace,
}) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(
        friendlyError(error, fallback: fallback, stackTrace: stackTrace),
      ),
    ),
  );
}
