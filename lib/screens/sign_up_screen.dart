import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/country.dart';
import 'package:crowdpass/providers/auth_provider.dart';

import 'package:crowdpass/widgets/error_dialog.dart';
import 'package:crowdpass/widgets/editable_email_field.dart';
import 'package:crowdpass/widgets/editable_password_field.dart';
import 'package:crowdpass/widgets/editable_country_field.dart';
import 'package:crowdpass/widgets/editable_phone_field.dart';
import 'package:crowdpass/widgets/user_avatar.dart';

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
  String? _photoPath;

  // Guard to avoid attaching multiple listeners on rebuilds.
  bool _didSetupListener = false;

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Creating account...'),
        duration: Duration(seconds: 2),
      ),
    );

    // Call the notifier. Errors are caught by the listener below.
    await ref.read(authNotifier.notifier).signUp(
          email: _email.trim(),
          password: _password.trim(),
          displayName: _displayName.trim(),
          photoPath: _photoPath,
          phone: _phone.trim(),
          country: _country,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authActionState = ref.watch(authNotifier);
    final isLoading = authActionState.isLoading;

    // Riverpod requires ref.listen to be called during build.
    if (!_didSetupListener) {
      _didSetupListener = true;

      // Listen to the ACTION state (success/error/loading)
      ref.listen<AsyncValue<void>>(authNotifier, (previous, next) {
        next.whenOrNull(
          data: (_) {
            if (!mounted) return;
            // Action succeeded.
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            Navigator.of(context).pushReplacementNamed('/home/');
          },
          error: (error, stack) {
            if (!mounted) return;

            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ErrorDialog.show(
              context,
              title: 'Sign Up Failed',
              message: error.toString(),
            );
          },
        );
      });
    }

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
                  Center(
                    child: UserAvatar.medium(
                      isEditable: true,
                      photoURL: _photoPath,
                      onNameChanged: (value) =>
                          setState(() => _displayName = value),
                      onPhotoChanged: (value) =>
                          setState(() => _photoPath = value),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Display name required'
                          : null,
                    ),
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

                  const SizedBox(height: 32),

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