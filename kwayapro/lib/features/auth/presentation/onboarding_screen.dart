import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

import '../../../shared/models/enums.dart';
import '../domain/auth_providers.dart';
import '../domain/models/app_user.dart';
import '../../choir/data/choir_repository.dart';
import '../../choir/domain/models/choir.dart';
import '../../choir/domain/models/choir_membership.dart';
import '../../choir/domain/choir_providers.dart';

final pendingInviteCodeProvider = StateProvider<String?>((ref) => null);

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  bool _isLoading = false;

  // Auth method: 'phone' or 'email'
  String _authMethod = 'phone';

  // Step 1: Phone
  final _phoneController = TextEditingController();
  String? _verificationId;
  int? _resendToken;           // ForceResendingToken for resending without throttle

  // Step 1b: Email (alternative to phone)
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Step 2: OTP
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  // Step 3: Profile
  final _nameController = TextEditingController();
  File? _profileImage;
  final ImagePicker _imagePicker = ImagePicker();

  // Step 4: Join/Create
  bool _isCreating = false;
  bool _isJoining = false;
  final _choirNameController = TextEditingController();
  final _churchNameController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  String? _pendingChoirId;

  // Step 5: Voice Part
  VoicePart? _selectedPart;

  @override
  void dispose() {
    _phoneController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    _nameController.dispose();
    _choirNameController.dispose();
    _churchNameController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  void _nextStep() => setState(() => _step++);
  void _prevStep() => setState(() => _step--);

  Future<void> _sendPhoneCode({bool isResend = false}) async {
    final phoneStr = _phoneController.text.trim();
    if (phoneStr.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 9-digit phone number')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.verifyPhone(
        phoneNumber: '0$phoneStr',
        resendToken: isResend ? _resendToken : null,

        // ── 1. Instant verification / SMS Retriever auto-fill ────────────────
        // Firebase resolved the credential automatically — skip OTP step.
        onVerificationCompleted: (credential) async {
          final result = await ref
              .read(authRepositoryProvider)
              .signInWithCredential(credential);
          if (result.user != null && mounted) {
            setState(() {
              _isLoading = false;
              // Jump directly to profile step
              _step = 3;
            });
          }
        },

        // ── 2. SMS sent — user enters code manually ──────────────────────────
        onCodeSent: (verificationId, resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _resendToken = resendToken;
              _isLoading = false;
              if (!isResend) _nextStep();
            });
          }
        },

        // ── 3. Verification request failed ───────────────────────────────────
        onVerificationFailed: (e) {
          setState(() => _isLoading = false);
          if (!mounted) return;
          String message;
          if (e.code == 'invalid-phone-number') {
            message = 'The phone number format is invalid.';
          } else if (e.code == 'too-many-requests') {
            message = 'SMS quota exceeded. Please try again later.';
          } else if (e.code == 'missing-activity-for-recaptcha') {
            message = 'reCAPTCHA could not be shown. Restart the app and try again.';
          } else {
            message = 'Verification failed: ${e.message}';
          }
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        },

        // ── 4. Auto-retrieval timed out (60 s) ──────────────────────────────
        onCodeAutoRetrievalTimeout: (verificationId) {
          // Keep verificationId in case user enters the code after timeout
          if (mounted) setState(() => _verificationId = verificationId);
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _verifyOTP() async {
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length != 6) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.verifyOTP(verificationId: _verificationId!, smsCode: code);
      setState(() {
        _isLoading = false;
        _nextStep();
      });
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        if (e.code == 'invalid-verification-code') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incorrect code. Try again.')),
          );
        } else if (e.code == 'session-expired') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session expired. Try again.')),
          );
          _prevStep();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.message}')),
          );
        }
      }
    }
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.signInWithEmailAndPassword(email: email, password: password);
      if (mounted) {
        // Email sign-in successful, go to profile step
        setState(() {
          _isLoading = false;
          _step = 3; // Skip to profile step
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        String message;
        if (e.code == 'user-not-found') {
          message = 'No account found with this email.';
        } else if (e.code == 'wrong-password') {
          message = 'Incorrect password.';
        } else if (e.code == 'invalid-email') {
          message = 'Invalid email address.';
        } else if (e.code == 'user-disabled') {
          message = 'This account has been disabled.';
        } else {
          message = 'Error: ${e.message}';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _createAccountWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.createUserWithEmailAndPassword(email: email, password: password);
      if (mounted) {
        // Account created, go to profile step
        setState(() {
          _isLoading = false;
          _step = 3; // Skip to profile step
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        String message;
        if (e.code == 'email-already-in-use') {
          message = 'An account with this email already exists.';
        } else if (e.code == 'invalid-email') {
          message = 'Invalid email address.';
        } else if (e.code == 'weak-password') {
          message = 'Password is too weak.';
        } else {
          message = 'Error: ${e.message}';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  void _submitProfile() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }
    
    // Check deep link
    final pendingInvite = ref.read(pendingInviteCodeProvider);
    if (pendingInvite != null) {
      _inviteCodeController.text = pendingInvite;
      _joinChoir(); // Skip step 4, go straight to join
    } else {
      _nextStep();
    }
  }

  Future<void> _joinChoir() async {
    final code = _inviteCodeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);
    final repo = ref.read(choirRepositoryProvider);
    final choir = await repo.getChoirByInviteCode(code);
    setState(() => _isLoading = false);

    if (choir != null) {
      setState(() {
        _isJoining = true;
        _isCreating = false;
        _pendingChoirId = choir.choirId;
      });
      _nextStep();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid invite code')),
        );
      }
    }
  }

  Future<void> _finishSetup() async {
    if (_selectedPart == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user found');
      
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // 1. User
      final userRef = db.collection('users').doc(user.uid);
      batch.set(userRef, AppUser(
        userId: user.uid,
        name: _nameController.text.trim(),
        phone: user.phoneNumber ?? '',
        createdAt: DateTime.now(),
      ).toJson());

      // 2a. Create Choir
      if (_isCreating) {
        final choirRef = db.collection('choirs').doc();
        final choirId = choirRef.id;
        batch.set(choirRef, Choir(
          choirId: choirId,
          name: _choirNameController.text.trim(),
          churchName: _churchNameController.text.trim(),
          leaderId: user.uid,
          inviteCode: ChoirRepository.generateInviteCode(),
          plan: ChoirPlan.free,
          songCount: 0,
          createdAt: DateTime.now(),
        ).toJson());

        final membershipRef = db.collection('choir_memberships').doc('${choirId}_${user.uid}');
        batch.set(membershipRef, ChoirMembership(
          choirId: choirId,
          userId: user.uid,
          name: user.displayName ?? 'Leader',
          role: MemberRole.leader,
          defaultVoicePart: _selectedPart!,
          permissions: [],
          joinedAt: DateTime.now(),
        ).toJson());
        
        _pendingChoirId = choirId;
      }

      // 2b. Join Choir
      if (_isJoining && _pendingChoirId != null) {
        final membershipRef = db.collection('choir_memberships').doc('${_pendingChoirId}_${user.uid}');
        batch.set(membershipRef, ChoirMembership(
          choirId: _pendingChoirId!,
          userId: user.uid,
          name: user.displayName ?? 'Member',
          role: MemberRole.chorister,
          defaultVoicePart: _selectedPart!,
          permissions: [],
          joinedAt: DateTime.now(),
        ).toJson());
      }

      await batch.commit();

      // Clear pending invite
      ref.read(pendingInviteCodeProvider.notifier).state = null;

      // Set active choir
      await ref.read(activeChoirIdProvider.notifier).setChoir(_pendingChoirId);

      // We should ideally upload FCM token here, but handled in main.dart or home

      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Setup failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildStepContent(),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0: return _buildSplashStep();
      case 1: return _buildPhoneStep();
      case 2: return _buildOTPStep();
      case 3: return _buildProfileStep();
      case 4: return _buildJoinOrCreateStep();
      case 5: return _buildVoicePartStep();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildSplashStep() {
    return Center(
      key: const ValueKey('splash'),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Using a simple icon since SVG might not exist yet
            Icon(Icons.music_note, size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'KwayaPro',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'The digital home for African church choirs.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: _nextStep,
              icon: const Icon(Icons.arrow_right_alt),
              label: const Text('Get Started'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Padding(
      key: const ValueKey('phone'),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          // Auth method toggle
          Center(
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'phone', label: Text('Phone'), icon: Icon(Icons.phone)),
                ButtonSegment(value: 'email', label: Text('Email'), icon: Icon(Icons.email)),
              ],
              selected: {_authMethod},
              onSelectionChanged: (selection) {
                setState(() => _authMethod = selection.first);
              },
            ),
          ),
          const SizedBox(height: 32),
          if (_authMethod == 'phone') ...[
            Text(
              'Enter your phone number',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text('We will send you a verification code.'),
            const SizedBox(height: 32),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text('+256', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '770 123 456',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _sendPhoneCode,
              child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Send Code'),
            ),
          ] else ...[
            Text(
              'Sign in with email',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Enter your email and password to sign in or create an account.'),
            const SizedBox(height: 32),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _createAccountWithEmail,
                    child: const Text('Create Account'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _isLoading ? null : _signInWithEmail,
                    child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Sign In'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOTPStep() {
    return Padding(
      key: const ValueKey('otp'),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Text(
            'Verify code',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text('Enter the 6-digit code sent to +256${_phoneController.text}'),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) {
              return SizedBox(
                width: 45,
                child: TextFormField(
                  controller: _otpControllers[index],
                  focusNode: _otpFocusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  decoration: InputDecoration(
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty && index < 5) {
                      _otpFocusNodes[index + 1].requestFocus();
                    }
                    if (value.isEmpty && index > 0) {
                      _otpFocusNodes[index - 1].requestFocus();
                    }
                  },
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading ? null : _verifyOTP,
            child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Verify & Continue'),
          ),
          const SizedBox(height: 16),
          // Resend code — uses ForceResendingToken to avoid throttling
          Center(
            child: TextButton(
              onPressed: _isLoading ? null : () => _sendPhoneCode(isResend: true),
              child: const Text('Resend code'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStep() {
    return Padding(
      key: const ValueKey('profile'),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Text(
            'Create profile',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                child: _profileImage == null
                    ? Icon(Icons.add_a_photo, size: 30, color: Theme.of(context).colorScheme.primary)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
          ),
          const Spacer(),
          FilledButton(
            onPressed: _submitProfile,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinOrCreateStep() {
    return Padding(
      key: const ValueKey('join_create'),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Text(
            'Join or Create a Choir',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          
          if (!_isJoining && !_isCreating) ...[
            Card(
              child: InkWell(
                onTap: () => setState(() => _isJoining = true),
                borderRadius: BorderRadius.circular(24),
                child: const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(Icons.group_add, size: 48),
                      SizedBox(height: 16),
                      Text('Join a Choir', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('I have an invite code'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: InkWell(
                onTap: () => setState(() => _isCreating = true),
                borderRadius: BorderRadius.circular(24),
                child: const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(Icons.add_business, size: 48),
                      SizedBox(height: 16),
                      Text('Create a Choir', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('I am the leader/director'),
                    ],
                  ),
                ),
              ),
            ),
          ] else if (_isJoining) ...[
            TextFormField(
              controller: _inviteCodeController,
              decoration: const InputDecoration(
                labelText: 'Invite Code',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _isJoining = false),
                  child: const Text('Back'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _isLoading ? null : _joinChoir,
                  child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Verify Code'),
                ),
              ],
            ),
          ] else if (_isCreating) ...[
            TextFormField(
              controller: _choirNameController,
              decoration: const InputDecoration(
                labelText: 'Choir Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _churchNameController,
              decoration: const InputDecoration(
                labelText: 'Church/Parish Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _isCreating = false),
                  child: const Text('Back'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    if (_choirNameController.text.isNotEmpty && _churchNameController.text.isNotEmpty) {
                      _nextStep();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill all fields')),
                      );
                    }
                  },
                  child: const Text('Next'),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildVoicePartStep() {
    return Padding(
      key: const ValueKey('voice_part'),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Text(
            'What is your voice part?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          for (final part in VoicePart.values) ...[
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: _selectedPart == part ? Theme.of(context).colorScheme.primary : null,
                foregroundColor: _selectedPart == part ? Theme.of(context).colorScheme.onPrimary : null,
                side: BorderSide(
                  color: _selectedPart == part 
                      ? Theme.of(context).colorScheme.primary 
                      : Theme.of(context).colorScheme.outline,
                ),
                padding: const EdgeInsets.all(16),
              ),
              onPressed: () => setState(() => _selectedPart = part),
              child: Text(part.displayName, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 16),
          ],
          const Spacer(),
          FilledButton(
            onPressed: _selectedPart == null || _isLoading ? null : _finishSetup,
            child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Finish Setup'),
          ),
        ],
      ),
    );
  }
}
