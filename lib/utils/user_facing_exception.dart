/// An error whose message was written for the user, not the developer.
///
/// [friendlyError] swaps unknown exceptions for a generic fallback so internals
/// never leak. Throw this instead when the server has already produced a
/// specific, safe explanation — "You're out of try-on credits." is far more
/// useful than "Try-on failed. Please try again."
///
/// [code] is the machine-readable code from the edge function
/// (`insufficient_credits`, `unauthenticated`, `daily_cap_reached`) so callers
/// can branch — e.g. routing to a purchase sheet rather than showing a snackbar.
class UserFacingException implements Exception {
  const UserFacingException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
