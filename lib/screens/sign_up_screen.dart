import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Providers
import 'package:crowdpass/providers/auth_provider.dart';

import 'package:crowdpass/widgets/error_dialog.dart';
import 'package:crowdpass/widgets/editable_email_field.dart';
import 'package:crowdpass/widgets/editable_password_field.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _email;
  String? _password;
  String? _displayName;

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    // Show loading snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Creating account...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      await ref
          .read(authNotifier.notifier)
          .signUp(
            email: _email!.trim(),
            password: _password!.trim(),
            displayName: _displayName!.trim(),
          );
    } catch (e) {
      ErrorDialog.show(context, title: 'Sign Up Failed', message: e.toString());
    } finally {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Check authProvider for existing signup/signin
    ref.listen<AsyncValue<User?>>(authProvider, (previousState, nextState) {
      nextState.whenData((user) {
        if (user != null) {
          Navigator.of(context).pushReplacementNamed('/home/');
        }
      });
    });

    final isLoading = ref.watch(authProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => _displayName = value.trim(),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Display name required'
                        : null,
                  ),
                  
                  const SizedBox(height: 16),

                  EditableEmailField(
                    isEditable: true,
                    onChanged: (value) => _email = value.trim(),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Invalid email'
                        : null,
                  ),

                  const SizedBox(height: 16),

                  EditablePasswordField(
                    onChanged: (value) => _password = value.trim(),
                    validator: (value) => (value == null || value.length < 6)
                        ? 'Min 6 characters'
                        : null,
                  ),

                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: isLoading ? null : _signUp,
                    child: const Text('Create Account'),
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
