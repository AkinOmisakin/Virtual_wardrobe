import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:virtual_wardrobe/utils/error_messages.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _loadingGoogle = false;
  bool _loadingApple = false;
  String? _error;
  final _googleSignIn = GoogleSignIn.instance;
  bool _isGoogleSignInInitialized = false;

  _LoginPageState() {
    _initializeGoogleSignIn();
  }

  Future<void> _initializeGoogleSignIn() async {
    try {
      await _googleSignIn.initialize(
        // Web Client ID from Google Cloud Console → Credentials.
        // Must match the Client ID configured in Supabase → Auth → Google.
      );
      _isGoogleSignInInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize Google Sign-In: $e');
    }
  }

  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_isGoogleSignInInitialized) {
      await _initializeGoogleSignIn();
    }
  }

  // ── Google ─────────────────────────────────────────────────────────────────

  Future<void> _signInWithGoogle() async {
    await _ensureGoogleSignInInitialized();
    setState(() { _loadingGoogle = true; _error = null; });
    try {
      final googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email'],
      );

      final idToken = googleUser.authentication.idToken;
      if (idToken == null) throw Exception('Google ID token unavailable');

      // accessToken is optional for Supabase; only request it if scopes need it
      String? accessToken;
      try {
        final authorization = await _googleSignIn.authorizationClient
            .authorizationForScopes(['email']);
        accessToken = authorization?.accessToken;
      } catch (_) {
        // non-fatal — Supabase only strictly needs the idToken
      }

      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user != null) {
        await _ensureUserDoc(
          uid: response.user!.id,
          displayName: googleUser.displayName,
          avatarUrl: googleUser.photoUrl,
        );
      }
    } catch (e, st) {
      debugPrint('Google sign-in error: $e\n$st');
      if (mounted) {
        setState(() => _error = friendlyError(e,
            fallback: 'Google sign-in failed. Please try again.',
            stackTrace: st));
      }
    } finally {
      if (mounted) setState(() => _loadingGoogle = false);
    }
  }

  // ── Apple ──────────────────────────────────────────────────────────────────

  Future<void> _signInWithApple() async {
    setState(() { _loadingApple = true; _error = null; });
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken = appleCredential.identityToken;
      if (idToken == null) throw Exception('Apple identity token unavailable');

      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
      );

      if (response.user != null) {
        final givenName  = appleCredential.givenName;
        final familyName = appleCredential.familyName;
        final fullName   = [givenName, familyName]
            .whereType<String>()
            .join(' ')
            .trim();
        await _ensureUserDoc(
          uid: response.user!.id,
          displayName: fullName.isNotEmpty ? fullName : null,
          avatarUrl: null,
        );
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled) {
        if (mounted) setState(() => _error = 'Apple sign-in failed. Please try again.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Apple sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loadingApple = false);
    }
  }

  // ── Supabase profiles upsert ───────────────────────────────────────────────

  Future<void> _ensureUserDoc({
    required String uid,
    String? displayName,
    String? avatarUrl,
  }) async {
    final name = displayName?.isNotEmpty == true ? displayName! : 'Cher user';
    final username = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    await Supabase.instance.client.from('profiles').upsert(
      {
        'id':         uid,
        'name':       name,
        'username':   username,
        'avatar_url': avatarUrl,
        'bio':        '',
      },
      onConflict: 'id',
      ignoreDuplicates: true,
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final showApple = Platform.isIOS || Platform.isMacOS;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),

              Text(
                'Cher.',
                style: GoogleFonts.robotoMono(
                  fontSize: 42,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your digital wardrobe.',
                style: GoogleFonts.robotoMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w300,
                  color: Colors.grey[500],
                ),
              ),

              const Spacer(flex: 3),

              _SignInButton(
                loading: _loadingGoogle,
                onTap: _signInWithGoogle,
                logo: _GoogleLogo(),
                label: 'Continue with Google',
              ),

              if (showApple) ...[
                const SizedBox(height: 12),
                _SignInButton(
                  loading: _loadingApple,
                  onTap: _signInWithApple,
                  logo: const Icon(Icons.apple, size: 22, color: Colors.black),
                  label: 'Continue with Apple',
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Text(
                    _error!,
                    style: GoogleFonts.robotoMono(
                        fontSize: 11, color: Colors.red[700]),
                  ),
                ),
              ],

              const Spacer(flex: 2),

              Center(
                child: Text(
                  'By continuing you agree to our Terms & Privacy Policy.',
                  style: GoogleFonts.robotoMono(
                    fontSize: 9,
                    color: Colors.grey[400],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SignInButton extends StatelessWidget {
  const _SignInButton({
    required this.loading,
    required this.onTap,
    required this.logo,
    required this.label,
  });

  final bool loading;
  final VoidCallback onTap;
  final Widget logo;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedOpacity(
        opacity: loading ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: loading
              ? const Center(
                  child: SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    logo,
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: GoogleFonts.robotoMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Draws the Google 'G' logo using coloured arcs — no asset file needed.
class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22, height: 22,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2;

    const blue   = Color(0xFF4285F4);
    const red    = Color(0xFFEA4335);
    const yellow = Color(0xFFFBBC05);
    const green  = Color(0xFF34A853);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round;

    paint.color = blue;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -0.52, 2.79, false, paint);
    paint.color = red;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -2.26, 1.52, false, paint);
    paint.color = yellow;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        2.27, 0.79, false, paint);
    paint.color = green;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        3.06, 0.75, false, paint);

    paint
      ..color  = blue
      ..style  = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - size.height * 0.09,
          r * 0.95, size.height * 0.18),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
