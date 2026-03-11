import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/providers/auth_provider.dart';

import 'package:crowdpass/widgets/error_dialog.dart';
import 'package:crowdpass/widgets/round_icon_button.dart';
import 'package:crowdpass/widgets/radial_expansion_hero.dart';

enum UserAvatarSize { small, medium, large }

class UserAvatar extends ConsumerStatefulWidget {
  final String? displayName;
  final bool isEditable;
  final VoidCallback? onTap;
  final Function(String)? onNameChanged;
  final Function(String)? onPhotoChanged;
  final String? photoURL;
  final UserAvatarSize size;
  final String? userId;
  final FormFieldValidator<String>? validator;

  const UserAvatar({
    super.key,
    this.displayName,
    this.isEditable = false,
    this.onNameChanged,
    this.onPhotoChanged,
    this.onTap,
    this.photoURL,
    required this.size,
    this.userId,
    this.validator,
  });

  const UserAvatar.small({
    super.key,
    this.displayName,
    this.isEditable = false,
    this.onNameChanged,
    this.onPhotoChanged,
    this.onTap,
    this.photoURL,
    this.userId,
    this.validator,
  }) : size = UserAvatarSize.small;

  const UserAvatar.medium({
    super.key,
    this.displayName,
    this.isEditable = false,
    this.onNameChanged,
    this.onPhotoChanged,
    this.onTap,
    this.photoURL,
    this.userId,
    this.validator,
  }) : size = UserAvatarSize.medium;

  const UserAvatar.large({
    super.key,
    this.displayName,
    this.isEditable = false,
    this.onNameChanged,
    this.onPhotoChanged,
    this.onTap,
    this.photoURL,
    this.userId,
    this.validator,
  }) : size = UserAvatarSize.large;

  @override
  ConsumerState<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends ConsumerState<UserAvatar> {
  String? _localPhotoPath;

  Future<void> _changePhoto() async {
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (file != null) {
        setState(() {
          _localPhotoPath = file.path;
        });
        widget.onPhotoChanged?.call(file.path);
      }
    } catch (error) {
      ErrorDialog.show(
        context,
        title: 'Failed to upload photo',
        message: error.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = switch (widget.size) {
      UserAvatarSize.small => 24.0,
      UserAvatarSize.medium => 48.0,
      UserAvatarSize.large => 96.0,
    };

    final buttonRadius = 20.0;
    final buttonOffset = Offset(
      radius * math.cos(math.pi / 4) + radius - buttonRadius,
      radius * math.sin(math.pi / 4) + radius - buttonRadius,
    );

    final String? displayName = widget.displayName ?? ref.watch(authProvider).value?.displayName;
    final String? photoURL = _localPhotoPath ?? widget.photoURL ?? ref.watch(authProvider).value?.photoURL;
    final bool hasPhoto = photoURL != null && photoURL.isNotEmpty;

    // Optimized ImageProvider logic
    ImageProvider? imageProvider;
    if (hasPhoto) {
      if (photoURL.startsWith('http')) {
        imageProvider = NetworkImage(photoURL);
      } else {
        imageProvider = FileImage(File(photoURL));
      }
    }

    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.onTap,
                child: CircleAvatar(
                  radius: radius,
                  foregroundImage: imageProvider,
                  child: hasPhoto
                      ? RadialExpansionHero(
                          photo: photoURL,
                          radius: radius,
                        )
                      : Icon(
                          Icons.person,
                          size: radius,
                          color: theme.colorScheme.onSurface,
                        ),
                ),
              ),
            ),
            if (widget.isEditable)
              Positioned(
                top: buttonOffset.dy,
                left: buttonOffset.dx,
                child: RoundIconButton(
                  icon: const Icon(Icons.photo_camera),
                  radius: buttonRadius,
                  onPressed: _changePhoto,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        widget.isEditable
          ? TextFormField(
              initialValue: displayName,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: const InputDecoration(labelText: 'User Name'),
              onChanged: widget.onNameChanged,
              style: theme.textTheme.titleLarge,
              maxLength: 20,
              textAlign: TextAlign.center,
              validator: (text) {
                if (text == null || text.isEmpty) {
                  return 'Please enter your name';
                } else if (text.length < 2 || text.length > 20) {
                  return 'Name must be between 2 and 20 characters';
                }
                return widget.validator?.call(text);
              },
            )
          : Text(displayName ?? '', style: theme.textTheme.titleLarge),
      ],
    );
  }
}