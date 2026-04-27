import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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
  GoogleSignInAccount? _currentUser;

  _LoginPageState() {
    _initializeGoogleSignIn();
    if (_currentUser == null) {
      attemptSilentSignIn().then((account) {
        if (account != null) {
          setState(() => _currentUser = account);
        }
      });
    }
    // attemptSilentSignIn().then((account) {
    //   if (account != null) {
    //     setState(() => _currentUser = account);
    //   }
    // });
    // debugPrint(_currentUser!.id);
  } 

  Future<void> _initializeGoogleSignIn() async {
    try {
      await _googleSignIn.initialize();
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

  Future<UserCredential> signInWithGoogleFirebase() async {
    await _ensureGoogleSignInInitialized();

    // Authenticate with Google
    final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(
      scopeHint: ['email'],
    );

    // Get authorization for Firebase scopes if needed
    final authClient = _googleSignIn.authorizationClient;
    final authorization = await authClient.authorizationForScopes(['email']);


    final credential = GoogleAuthProvider.credential(
      accessToken: authorization?.accessToken,
      idToken: googleUser.authentication.idToken,
    );

    final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

    // Update local state
    _currentUser = googleUser;

    return userCredential;
  }

  Future<GoogleSignInAccount?> attemptSilentSignIn() async {
    await _ensureGoogleSignInInitialized();

    try {
      // attemptLightweightAuthentication can return Future or immediate result
      final result = _googleSignIn.attemptLightweightAuthentication();

      // Handle both sync and async returns
      if (result is Future<GoogleSignInAccount?>) {
        return await result;
      } else {
        return result as GoogleSignInAccount?;
      }
    } catch (error) {
      debugPrint('Silent sign-in failed: $error');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
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

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken:     appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(oauthCredential);

      // Apple only returns the name on the very first sign-in.
      final givenName  = appleCredential.givenName;
      final familyName = appleCredential.familyName;
      final fullName   = [givenName, familyName]
          .whereType<String>()
          .join(' ')
          .trim();

      await _ensureUserDoc(userCredential.user!, displayName: fullName);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled) {
        setState(() => _error = 'Apple sign-in failed. Please try again.');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendly(e.code));
    } catch (_) {
      setState(() => _error = 'Apple sign-in failed. Please try again.');
    } finally {
      if (mounted) setState(() => _loadingApple = false);
    }
  }

  // ── Phone ──────────────────────────────────────────────────────────────────

  // Future<void> _signInWithPhone() async {
  //   setState(() => _error = null);
  //   await showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     backgroundColor: Colors.white,
  //     shape: const RoundedRectangleBorder(
  //       borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  //     ),
  //     builder: (_) => const _PhoneSheet(),
  //   );
  // }

  // ── Firestore user doc ─────────────────────────────────────────────────────

  /// Creates a user document only on first sign-in (uses merge so repeat
  /// sign-ins don't overwrite name / avatar the user may have updated).
  Future<void> _ensureUserDoc(User user, {String? displayName}) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snapshot = await ref.get();

    if (!snapshot.exists) {
      final name = displayName?.isNotEmpty == true
          ? displayName!
          : (user.displayName ?? 'Cher user');
      // Derive a default username from the display name.
      final username = name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '_')
          .replaceAll(RegExp(r'_+'), '_');

      await ref.set({
        'name':      name,
        'username':  username,
        'avatarUrl': user.photoURL,
        'bio':       '',
        'createdAt': DateTime.now().toIso8601String(),
      });
    }
  }

  // ── error helper ───────────────────────────────────────────────────────────

  String _friendly(String code) => switch (code) {
    'account-exists-with-different-credential' =>
        'An account already exists with a different sign-in method.',
    'network-request-failed' => 'No internet connection.',
    'too-many-requests'      => 'Too many attempts. Please try again later.',
    _                        => 'Something went wrong. Please try again.',
  };

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Show Apple button only on iOS / macOS.
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

              // ── wordmark ──────────────────────────────────────────────
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

              // ── sign-in buttons ───────────────────────────────────────
              _SignInButton(
                loading: _loadingGoogle,
                onTap: signInWithGoogleFirebase,
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

              const SizedBox(height: 12),

              // _SignInButton(
              //   loading: false,
              //   onTap: _signInWithPhone,
              //   logo: const Icon(Icons.phone_outlined,
              //       size: 20, color: Colors.black),
              //   label: 'Continue with phone',
              // ),

              // ── error ─────────────────────────────────────────────────
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

              // ── legal note ────────────────────────────────────────────
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
// Phone sign-in bottom sheet  (number entry → OTP verification)
// ─────────────────────────────────────────────────────────────────────────────

class _PhoneSheet extends StatefulWidget {
  const _PhoneSheet();

  @override
  State<_PhoneSheet> createState() => _PhoneSheetState();
}

class _PhoneSheetState extends State<_PhoneSheet> {
  // Stages: 'number' → 'otp'
  String _stage = 'number';

  final _numberController = TextEditingController();
  final _otpController    = TextEditingController();
  String? _verificationId;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _numberController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ── send OTP ───────────────────────────────────────────────────────────────

  Future<void> _sendCode() async {
    final number = _numberController.text.trim();
    if (number.isEmpty) {
      setState(() => _error = 'Please enter your phone number.');
      return;
    }
    setState(() { _loading = true; _error = null; });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: number,
      timeout: const Duration(seconds: 60),

      // Auto-retrieval (Android SMS autofill / instant verification)
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _signInWithCredential(credential);
      },

      verificationFailed: (FirebaseAuthException e) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = _friendlyPhone(e.code);
          });
        }
      },

      codeSent: (String verificationId, int? resendToken) {
        if (mounted) {
          setState(() {
            _verificationId = verificationId;
            _stage = 'otp';
            _loading = false;
          });
        }
      },

      codeAutoRetrievalTimeout: (_) {},
    );
  }

  // ── verify OTP ─────────────────────────────────────────────────────────────

  Future<void> _verifyCode() async {
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      setState(() => _error = 'Please enter the 6-digit code.');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode:        otp,
      );
      await _signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error   = _friendlyPhone(e.code);
        _loading = false;
      });
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    final userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);
    await _ensureUserDoc(userCredential.user!);
    if (mounted) Navigator.of(context).pop();
    // AuthGate stream fires → Start.
  }

  Future<void> _ensureUserDoc(User user) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      final phone = user.phoneNumber ?? '';
      await ref.set({
        'name':      'Cher user',
        'username':  'user_${phone.replaceAll(RegExp(r'[^0-9]'), '').substring(0, 4)}',
        'avatarUrl': null,
        'bio':       '',
        'createdAt': DateTime.now().toIso8601String(),
      });
    }
  }

  String _friendlyPhone(String code) => switch (code) {
    'invalid-phone-number'   => 'Invalid phone number. Include country code (e.g. +44).',
    'too-many-requests'      => 'Too many attempts. Try again later.',
    'invalid-verification-code' => 'Incorrect code. Please try again.',
    'session-expired'        => 'Code expired. Please request a new one.',
    'network-request-failed' => 'No internet connection.',
    _                        => 'Something went wrong. Please try again.',
  };

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        left: 28, right: 28, top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // drag handle
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            _stage == 'number' ? 'Enter your number' : 'Enter the code',
            style: GoogleFonts.robotoMono(
                fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            _stage == 'number'
                ? 'Include your country code, e.g. +44 7700 900000'
                : 'We sent a 6-digit code to ${_numberController.text.trim()}',
            style: GoogleFonts.robotoMono(
                fontSize: 11, color: Colors.grey[500]),
          ),

          const SizedBox(height: 24),

          if (_stage == 'number')
            _PhoneField(
              controller: _numberController,
              label: 'Phone number',
              keyboardType: TextInputType.phone,
            )
          else
            _PhoneField(
              controller: _otpController,
              label: '6-digit code',
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: GoogleFonts.robotoMono(
                    fontSize: 11, color: Colors.red[600])),
          ],

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: _loading
                  ? null
                  : (_stage == 'number' ? _sendCode : _verifyCode),
              child: _loading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _stage == 'number' ? 'Send code' : 'Verify',
                      style: GoogleFonts.robotoMono(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
            ),
          ),

          if (_stage == 'otp') ...[
            const SizedBox(height: 14),
            Center(
              child: GestureDetector(
                onTap: _loading ? null : () {
                  setState(() {
                    _stage = 'number';
                    _otpController.clear();
                    _error = null;
                  });
                },
                child: Text(
                  'Change number',
                  style: GoogleFonts.robotoMono(
                    fontSize: 12,
                    color: Colors.grey[500],
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ],
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

    // Colours
    const blue   = Color(0xFF4285F4);
    const red    = Color(0xFFEA4335);
    const yellow = Color(0xFFFBBC05);
    const green  = Color(0xFF34A853);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.round;

    // Blue arc (right + top)
    paint.color = blue;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -0.52, 2.79, false, paint);
    // Red arc (top-left)
    paint.color = red;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -2.26, 1.52, false, paint);
    // Yellow arc (bottom-left)
    paint.color = yellow;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        2.27, 0.79, false, paint);
    // Green arc (bottom-right)
    paint.color = green;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        3.06, 0.75, false, paint);

    // Blue horizontal bar (the crossbar in the G)
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

class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    required this.label,
    required this.keyboardType,
    this.maxLength,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      autofocus: true,
      style: GoogleFonts.robotoMono(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        labelStyle: GoogleFonts.robotoMono(
            fontSize: 12, color: Colors.grey[500]),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.black, width: 1.5),
        ),
      ),
    );
  }
}