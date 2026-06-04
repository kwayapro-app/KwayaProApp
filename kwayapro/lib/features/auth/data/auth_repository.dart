import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/repositories/base_repository.dart';
import '../../../core/utils/phone_normaliser.dart';

/// Wraps Firebase phone-number and email/password authentication
class AuthRepository extends BaseRepository {
  final FirebaseAuth _auth;

  AuthRepository({
    super.firestore,
    FirebaseAuth? auth,
  }) : _auth = auth ?? FirebaseAuth.instance;

  // ---------------------------------------------------------------------------
  // Auth state
  // ---------------------------------------------------------------------------

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ---------------------------------------------------------------------------
  // Email/Password Authentication
  // ---------------------------------------------------------------------------

  /// Creates a new user account with email and password
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Signs in an existing user with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sends a password reset email to the specified email address
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ---------------------------------------------------------------------------
  // Phone number verification
  //
  // Mirrors the OnVerificationStateChangedCallbacks from the Android SDK:
  //   • onVerificationCompleted — instant or auto-retrieved credential
  //   • onVerificationFailed    — invalid number, quota exceeded, reCAPTCHA
  //   • onCodeSent              — code dispatched; provides verificationId +
  //                               ForceResendingToken for retries
  //   • onCodeAutoRetrievalTimeout — SMS auto-retrieval timed out
  // ---------------------------------------------------------------------------

  Future<void> verifyPhone({
    required String phoneNumber,
    /// Called when Firebase auto-verifies the number (instant verification or
    /// SMS Retriever API). Sign in immediately with the supplied credential.
    required void Function(PhoneAuthCredential credential) onVerificationCompleted,
    /// Called when verification fails (bad number, quota, reCAPTCHA missing).
    required void Function(FirebaseAuthException e) onVerificationFailed,
    /// Called after the SMS code is sent. Store [verificationId] and
    /// [resendToken] to verify the OTP or resend the code later.
    required void Function(String verificationId, int? resendToken) onCodeSent,
    /// Called when auto-retrieval times out without completing verification.
    void Function(String verificationId)? onCodeAutoRetrievalTimeout,
    /// Supply a previously received [ForceResendingToken] to resend the SMS
    /// without triggering rate-limiting.
    int? resendToken,
  }) async {
    final normalisedPhone = PhoneNormaliser.normalise(phoneNumber);

    await _auth.verifyPhoneNumber(
      phoneNumber: normalisedPhone,
      timeout: const Duration(seconds: 60),
      // 1. Instant verification / SMS Retriever auto-fill
      verificationCompleted: onVerificationCompleted,
      // 2. Verification request failed
      verificationFailed: onVerificationFailed,
      // 3. SMS sent — user must enter the 6-digit code manually
      codeSent: onCodeSent,
      // 4. Auto-retrieval timed out
      codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout ?? (_) {},
      // Pass resend token when the user requests a new code
      forceResendingToken: resendToken,
    );
  }

  // ---------------------------------------------------------------------------
  // OTP verification
  //
  // Constructs a PhoneAuthCredential from the verificationId + user-entered
  // code and signs in. Throws FirebaseAuthException on invalid/expired code.
  // ---------------------------------------------------------------------------

  Future<UserCredential> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  /// Sign in directly with a credential (used for instant verification).
  Future<UserCredential> signInWithCredential(
      PhoneAuthCredential credential) async {
    return _auth.signInWithCredential(credential);
  }

  // ---------------------------------------------------------------------------
  // FCM token
  // ---------------------------------------------------------------------------

  Future<void> updateFCMToken(String userId, String token) async {
    await db.collection('users').doc(userId).update({'fcmToken': token});
  }

  // ---------------------------------------------------------------------------
  // Sign out
  // ---------------------------------------------------------------------------

  Future<void> signOut() async => _auth.signOut();
}