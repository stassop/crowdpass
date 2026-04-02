import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:crowdpass/widgets/round_icon_button.dart';

class AnimatedAppBar extends StatefulWidget {
  final double maxHeight;
  final double? minHeight;
  final String? imageUrl;
  final String? photoURL;
  final String? title;
  final String? hintText;
  final Widget? leading;
  final List<Widget>? actions;
  final bool isEditable;
  final ValueChanged<String>? onTitleChanged;
  final ValueChanged<String>? onPhotoURLChanged;
  final String? Function(String?)? validator;

  const AnimatedAppBar({
    super.key,
    this.maxHeight = 200,
    this.title,
    this.hintText,
    this.imageUrl,
    this.photoURL,
    this.leading,
    this.actions,
    this.minHeight,
    this.isEditable = true,
    this.onTitleChanged,
    this.onPhotoURLChanged,
    this.validator,
  });

  @override
  State<AnimatedAppBar> createState() => _AnimatedAppBarState();
}

class _AnimatedAppBarState extends State<AnimatedAppBar> {
  late String? _photoURL;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _photoURL = widget.photoURL;
    _textController = TextEditingController(text: widget.title ?? '');
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      setState(() {
        _photoURL = pickedFile.path;
      });
      if (widget.onPhotoURLChanged != null) {
        widget.onPhotoURLChanged!(_photoURL!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isNetworkImage = widget.imageUrl?.startsWith('http') ?? false;
    final theme = Theme.of(context);

    return SliverAppBar(
      pinned: true,
      expandedHeight: widget.maxHeight,
      collapsedHeight: widget.minHeight ?? kToolbarHeight,
      leading: widget.leading,
      actions: widget.actions,
      flexibleSpace: ShaderMask(
        shaderCallback: (Rect bounds) {
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Colors.transparent, Colors.white],
            stops: [0.0, 0.5], // Adjust the second stop to control the fade length
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: FlexibleSpaceBar(
          centerTitle: true,
          titlePadding: const EdgeInsets.symmetric(horizontal: 64, vertical: 16),
          title: widget.isEditable
              ? TextFormField(
                  controller: _textController,
                  onChanged: widget.onTitleChanged,
                  textAlign: TextAlign.center,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: widget.hintText ?? 'Enter title',
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onPrimary.withAlpha(128),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.onPrimary.withAlpha(128),
                      ),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                    errorBorder: widget.validator != null
                        ? const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.redAccent,
                            ),
                          )
                        : null,
                    errorStyle: const TextStyle(
                      color: Colors.redAccent,
                    ),
                  ),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                  cursorColor: theme.colorScheme.onPrimary,
                  validator: widget.validator,
                )
              : Text(
                  widget.title ?? '',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
          background: Stack(
            fit: StackFit.expand,
            children: [
              _photoURL != null
                  ? Image.file(File(_photoURL!), fit: BoxFit.cover)
                  : widget.imageUrl != null
                      ? (isNetworkImage
                          ? Image.network(widget.imageUrl!, fit: BoxFit.cover)
                          : Image.file(File(widget.imageUrl!), fit: BoxFit.cover))
                      : Container(color: theme.primaryColor),
              if (widget.isEditable)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: RoundIconButton.small(
                    icon: const Icon(Icons.photo_camera),
                    onPressed: _pickImage,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}