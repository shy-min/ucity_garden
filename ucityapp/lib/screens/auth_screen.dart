import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';

import '../theme.dart';
import 'legal_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool isLogin = true;
  bool isLoading = false;
  bool acceptedTerms = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  String _friendly(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address doesn\'t look right.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account with that email already exists. Try signing in.';
      case 'weak-password':
        return 'Please choose a password with at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a minute and try again.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      showSnack(context, 'Please enter your email and password.');
      return;
    }
    if (!isLogin) {
      if (_firstNameController.text.trim().isEmpty) {
        showSnack(context, 'Please enter your first name.');
        return;
      }
      if (!acceptedTerms) {
        showSnack(context, 'Please agree to the Community Guidelines to continue.');
        return;
      }
    }
    setState(() => isLoading = true);
    try {
      if (isLogin) {
        await fb.FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      } else {
        final cred = await fb.FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'email': email,
          'joinedAt': Timestamp.now(),
          'acceptedTermsAt': Timestamp.now(),
          'blocked': <String>[],
        });
        await cred.user!.updateDisplayName(
            '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'.trim());
      }
    } on fb.FirebaseAuthException catch (e) {
      if (mounted) showSnack(context, _friendly(e));
    } catch (e) {
      if (mounted) showSnack(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _emailController.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Reset password'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Email', fillColor: AppColors.background),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Send link')),
        ],
      ),
    );
    if (email == null || email.isEmpty || !mounted) return;
    try {
      await fb.FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) showSnack(context, 'If an account exists for $email, a reset link is on its way.');
    } on fb.FirebaseAuthException catch (e) {
      if (mounted) showSnack(context, _friendly(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_florist, size: 64, color: AppColors.green),
                  const SizedBox(height: 12),
                  const Text(AppConfig.appName,
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  const Text(AppConfig.churchName, style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 36),
                  if (!isLogin) ...[
                    TextField(
                      controller: _firstNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'First Name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Last Name'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  if (isLogin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgotPassword,
                        child: const Text('Forgot password?', style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                  if (!isLogin)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(children: [
                        Checkbox(
                          value: acceptedTerms,
                          activeColor: AppColors.green,
                          onChanged: (v) => setState(() => acceptedTerms = v ?? false),
                        ),
                        Expanded(
                          child: Wrap(children: [
                            const Text('I agree to the '),
                            GestureDetector(
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => const LegalScreen(page: LegalPage.terms))),
                              child: const Text('Community Guidelines',
                                  style: TextStyle(color: AppColors.green, decoration: TextDecoration.underline)),
                            ),
                            const Text(' and '),
                            GestureDetector(
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => const LegalScreen(page: LegalPage.privacy))),
                              child: const Text('Privacy Policy',
                                  style: TextStyle(color: AppColors.green, decoration: TextDecoration.underline)),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                  const SizedBox(height: 16),
                  isLoading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(15)),
                            onPressed: _submit,
                            child: Text(isLogin ? 'Sign In' : 'Sign Up'),
                          ),
                        ),
                  TextButton(
                    onPressed: () => setState(() => isLogin = !isLogin),
                    child: Text(isLogin ? 'Create Account' : 'I have an account',
                        style: const TextStyle(color: AppColors.green)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
