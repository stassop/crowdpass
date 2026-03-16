import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/country.dart';
import 'package:crowdpass/providers/auth_provider.dart';
import 'package:crowdpass/providers/user_profile_provider.dart';

import 'package:crowdpass/widgets/editable_email_field.dart';
import 'package:crowdpass/widgets/editable_password_field.dart';
import 'package:crowdpass/widgets/editable_country_field.dart';
import 'package:crowdpass/widgets/editable_phone_field.dart';
import 'package:crowdpass/widgets/error_dialog.dart';
import 'package:crowdpass/widgets/user_avatar.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _displayName;
  String? _photoURL;
  String? _password;
  String? _phone;
  Country? _country;
  bool _isEditing = false;

  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate()) return;

    // Call the update method with ALL fields
    await ref.read(authNotifier.notifier).updateUser(
          displayName: _displayName,
          photoURL: _photoURL,
          password: _password,
          phone: _phone,
          country: _country,
        );

    // Check if the operation resulted in an error
    final authState = ref.read(authNotifier);
    if (authState.hasError) {
      if (mounted) {
        ErrorDialog.show(
          context,
          title: 'Update Failed',
          message: authState.error.toString(),
        );
      }
    } else {
      setState(() {
        _isEditing = false;
        _password = null; // Clear password field after success
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(authNotifier.notifier).deleteUser();
      
      final authState = ref.read(authNotifier);
      if (authState.hasError) {
        if (mounted) {
          ErrorDialog.show(context, title: 'Delete Failed', message: authState.error.toString());
        }
      } else {
        // Successful deletion usually triggers the auth stream to emit null, 
        // which handles the navigation if your router watches authState.
        if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final argsUserId = ModalRoute.of(context)?.settings.arguments as String?;
    final currentAuthUser = ref.watch(authProvider).value;
    final userAsync = ref.watch(userProfileProvider(argsUserId));
    final authState = ref.watch(authNotifier);

    return userAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
        ),
        body: Center(child: Text('Error loading profile: $err')),
      ),
      data: (user) {
        if (user == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Not Found'),
              leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
            ),
            body: const Center(child: Text('User profile not found.')),
          );
        }

        final isMe = currentAuthUser != null && currentAuthUser.uid == user.uid;
        
        // Comprehensive check to see if any field differs from the database
        final hasChanged = (_displayName != null && _displayName != user.displayName) ||
            (_photoURL != null && _photoURL != user.photoURL) ||
            (_phone != null && _phone != user.phone) ||
            (_country != null && _country != user.country) ||
            (_password != null && _password!.isNotEmpty);

        return Scaffold(
          appBar: AppBar(
            title: Text(isMe ? 'My Profile' : '${user.displayName}\'s Profile'),
            actions: [
              if (isMe)
                IconButton(
                  onPressed: authState.isLoading
                      ? null
                      : () {
                          if (_isEditing) {
                            hasChanged ? _updateUser() : setState(() => _isEditing = false);
                          } else {
                            setState(() => _isEditing = true);
                          }
                        },
                  icon: authState.isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_isEditing ? (hasChanged ? Icons.check : Icons.close) : Icons.edit),
                ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: UserAvatar.medium(
                        isEditable: isMe && _isEditing,
                        photoURL: _photoURL ?? user.photoURL,
                        displayName: _displayName ?? user.displayName,
                        onNameChanged: (value) => setState(() => _displayName = value),
                        onPhotoChanged: (value) => setState(() => _photoURL = value),
                      ),
                    ),

                    const SizedBox(height: 16),

                    EditableCountryField(
                      initialValue: user.country != null ? {user.country!} : null,
                      isEditable: isMe && _isEditing,
                      onChanged: (value) => setState(() => _country = value.first),
                    ),

                    const SizedBox(height: 16),

                    EditableEmailField(
                      initialValue: user.email,
                      isEditable: false,
                      onChanged: (_) {},
                    ),
                    
                    const SizedBox(height: 16),

                    EditablePhoneField(
                      initialValue: user.phone,
                      isEditable: isMe && _isEditing,
                      onChanged: (value) => setState(() => _phone = value),
                    ),

                    if (isMe && _isEditing) ...[
                      const SizedBox(height: 16),

                      EditablePasswordField(
                        onChanged: (value) => setState(() => _password = value),
                        validator: (value) => (value != null && value.isNotEmpty && value.length < 6)
                            ? 'Password must be at least 6 characters'
                            : null,
                      ),

                      const SizedBox(height: 32),

                      ElevatedButton.icon(
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('Delete Account'),
                        onPressed: authState.isLoading ? null : _deleteAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Theme.of(context).colorScheme.onError,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}