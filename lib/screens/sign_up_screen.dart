import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:crowdpass/models/country.dart';

import 'package:crowdpass/providers/auth_provider.dart';

import 'package:crowdpass/widgets/error_dialog.dart';
import 'package:crowdpass/widgets/editable_email_field.dart';
import 'package:crowdpass/widgets/editable_password_field.dart';
import 'package:crowdpass/widgets/editable_country_field.dart';
import 'package:crowdpass/widgets/editable_phone_field.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _email;
  late String _password;
  late String _phone;
  late Country _country;
  late String _displayName;
  String? _photoURL;
  
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
            email: _email.trim(),
            password: _password.trim(),
            displayName: _displayName.trim(),
            photoURL: _photoURL,
            phone: _phone.trim(),
            country: _country,
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
                    isRequired: true,
                    onChanged: (value) => _email = value.trim(),
                  ),

                  const SizedBox(height: 16),

                  EditablePasswordField(
                    isRequired: true,
                    onChanged: (value) => _password = value.trim(),
                  ),

                  const SizedBox(height: 16),

                  EditableCountryField(
                    isEditable: true,
                    onChanged: (value) => _country = value.first,
                    validator: (value) =>
                        (value.isEmpty) ? 'Select country' : null,
                  ),

                  const SizedBox(height: 16),

                  EditablePhoneField(
                    isEditable: true,
                    isRequired: true,
                    onChanged: (value) => _phone = value.trim(),
                  ),

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
