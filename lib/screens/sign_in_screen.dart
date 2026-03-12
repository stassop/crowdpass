import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/providers/auth_provider.dart';

import 'package:crowdpass/widgets/error_dialog.dart';
import 'package:crowdpass/widgets/editable_email_field.dart';
import 'package:crowdpass/widgets/editable_password_field.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _email;
  String? _password;

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Signing in...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      await ref
          .read(authNotifier.notifier)
          .signIn(email: _email!.trim(), password: _password!.trim());
    } catch (e) {
      ErrorDialog.show(context, title: 'Sign In Failed', message: e.toString());
    } finally {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the auth state to react to loading/data changes
    final authState = ref.watch(authProvider);

    // Listen for errors or successful login to trigger side effects
    ref.listen<AsyncValue<void>>(authNotifier, (previous, next) {
      next.whenOrNull(
        error: (error, stackTrace) {
          ErrorDialog.show(
            context,
            title: 'Failed to Sign In',
            message: error.toString(),
          );
        },
        data: (state) {
          Navigator.of(context).pushReplacementNamed('/home');
        },
      );
    });

    final isLoading = authState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    EditableEmailField(
                      isEditable: true,
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Please enter a valid email'
                          : null,
                      onChanged: (value) => _email = value,
                    ),
                    const SizedBox(height: 16),
                    EditablePasswordField(
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Please enter your password'
                          : null,
                      onChanged: (value) => _password = value,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: isLoading ? null : _signIn,
                      child: const Text('Sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
