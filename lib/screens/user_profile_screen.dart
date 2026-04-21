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
  String? _photoPath;
  String? _password;
  String? _phone;
  Country? _country;
  bool _isEditing = false;

  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await ref
          .read(authNotifier.notifier)
          .updateUser(
            displayName: _displayName,
            photoPath: _photoPath,
            password: _password,
            phone: _phone,
            country: _country,
          );

      if (!mounted) return;

      setState(() {
        _isEditing = false;
        _password = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    } catch (e) {
      if (mounted) {
        ErrorDialog.show(
          context,
          title: 'Update Failed',
          message: e.toString(),
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(authNotifier.notifier).deleteUser();

        if (!mounted) return;

        Navigator.of(context).pushReplacementNamed('/login');
      } catch (e) {
        if (mounted) {
          ErrorDialog.show(
            context,
            title: 'Delete Failed',
            message: e.toString(),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final argsUserId = ModalRoute.of(context)?.settings.arguments as String?;

    // Use SINGLE source of truth
    final authAsync = ref.watch(authNotifier);
    final currentAuthUser = ref.watch(authProvider).value;
    final userProfileAsync = ref.watch(userProfileProvider(argsUserId));

    final isLoading = authAsync.isLoading || userProfileAsync.isLoading;

    return userProfileAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          leading: BackButton(
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: Center(child: Text('Error loading profile: $err')),
      ),
      data: (userProfile) {
        if (userProfile == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Not Found'),
              leading: BackButton(
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            body: const Center(child: Text('User profile not found.')),
          );
        }

        final isMe = currentAuthUser != null && currentAuthUser.uid == userProfile.uid;

        final hasChanged =
            (_displayName != null && _displayName != userProfile.displayName) ||
            (_photoPath != null && _photoPath != userProfile.photoURL) ||
            (_phone != null && _phone != userProfile.phone) ||
            (_country != null && _country != userProfile.country) ||
            (_password != null && _password!.isNotEmpty);

        final theme = Theme.of(context);

        return Scaffold(
          appBar: AppBar(
            title: Text(isMe ? 'My Profile' : '${userProfile.displayName}\'s Profile'),
            actions: [
              if (isMe)
                IconButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          if (_isEditing) {
                            hasChanged
                                ? _updateUser()
                                : setState(() => _isEditing = false);
                          } else {
                            setState(() => _isEditing = true);
                          }
                        },
                  icon: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isEditing
                              ? (hasChanged ? Icons.check : Icons.edit_off)
                              : Icons.edit,
                        ),
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
                        photoURL: _photoPath ?? userProfile.photoURL,
                        displayName: _displayName ?? userProfile.displayName,
                        onNameChanged: (value) =>
                            setState(() => _displayName = value),
                        onPhotoChanged: (value) =>
                            setState(() => _photoPath = value),
                      ),
                    ),
                    const SizedBox(height: 16),
                    EditableEmailField(
                      initialValue: userProfile.email,
                      isEditable: false,
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: 16),
                    EditableCountryField(
                      initialValue: {userProfile.country},
                      isEditable: isMe && _isEditing,
                      onChanged: (value) =>
                          setState(() => _country = value.first),
                    ),
                    const SizedBox(height: 16),
                    EditablePhoneField(
                      initialValue: userProfile.phone,
                      isEditable: isMe && _isEditing,
                      onChanged: (value) => setState(() => _phone = value),
                    ),
                    if (isMe && _isEditing) ...[
                      const SizedBox(height: 16),
                      EditablePasswordField(
                        onChanged: (value) => setState(() => _password = value),
                        validator: (value) =>
                            (value != null &&
                                value.isNotEmpty &&
                                value.length < 6)
                            ? 'Password must be at least 6 characters'
                            : null,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('Delete Account'),
                        onPressed: isLoading ? null : _deleteAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
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
