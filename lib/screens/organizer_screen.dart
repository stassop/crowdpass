import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crowdpass/models/organizer.dart';
import 'package:crowdpass/providers/auth_provider.dart';
import 'package:crowdpass/providers/organizer_provider.dart';
import 'package:crowdpass/widgets/editable_iban_field.dart';
import 'package:crowdpass/widgets/editable_list_field.dart';
import 'package:crowdpass/widgets/editable_location_field.dart';
import 'package:crowdpass/widgets/editable_phone_field.dart';
import 'package:crowdpass/widgets/editable_text_field.dart';
import 'package:crowdpass/widgets/editable_website_field.dart';
import 'package:crowdpass/widgets/error_dialog.dart';
import 'package:crowdpass/widgets/user_avatar.dart';

class OrganizerScreen extends ConsumerStatefulWidget {
  const OrganizerScreen({super.key});

  @override
  ConsumerState<OrganizerScreen> createState() => _OrganizerScreenState();
}

class _OrganizerScreenState extends ConsumerState<OrganizerScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  String? _logoURL;
  Organizer? _organizerCopy;

  Future<void> _saveOrCreate() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authProvider).value;

    if (user == null) {
      ErrorDialog.show(
        context,
        title: 'Error',
        message: 'User not authenticated',
      );
      return;
    }

    if (_organizerCopy == null) {
      ErrorDialog.show(
        context,
        title: 'Error',
        message: 'Organizer data is missing.',
      );
      return;
    }

    try {
      // LOGIC FIX: Access the value correctly to determine if we are creating or updating.
      final organizerExists = ref.read(organizerProvider(user.uid)).value != null;

      if (!organizerExists) {
        await ref
            .read(organizerNotifier.notifier)
            .createOrganizer(_organizerCopy!, logoURL: _logoURL);
      } else {
        await ref
            .read(organizerNotifier.notifier)
            .updateOrganizer(_organizerCopy!, logoURL: _logoURL);
      }

      if (mounted) {
        setState(() => _isEditing = false);
      }
    } catch (e) {
      if (mounted) {
        ErrorDialog.show(context, title: 'Save Failed', message: 'Error: $e');
      }
    } finally {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authProvider);
    final isLoading = ref.watch(organizerNotifier).isLoading;

    return authAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Error'),
            leading: BackButton(
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          body: Center(child: Text('Auth Error: $err')),
        );
      },
      data: (user) {
        if (user == null) {
          return Scaffold(
            body: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Sign In'),
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/sign_in/',
                      (route) => false,
                    );
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.person_add),
                  label: const Text('Create Account'),
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/sign_up/',
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          );
        }

        final organizerAsync = ref.watch(organizerProvider(user.uid));

        return organizerAsync.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, stack) => Scaffold(
            appBar: AppBar(
              title: const Text('Error'),
              leading: BackButton(
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            body: Center(child: Text('Error: $err')),
          ),
          data: (organizer) {
            final isOrganizer =
                organizer != null && organizer.userId == user.uid;

            _isEditing = !isOrganizer; // Start in edit mode if no organizer profile exists.
            
            // LOGIC FIX: hasChanged should be true when objects are NOT equal.
            _organizerCopy ??= organizer;
            final hasChanged = _organizerCopy != organizer || _logoURL != null;

            return Scaffold(
              appBar: AppBar(
                title: const Text('Organizer Profile'),
                actions: [
                  if (isOrganizer)
                    IconButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              if (_isEditing) {
                                if (hasChanged) {
                                  _saveOrCreate();
                                } else {
                                  setState(() => _isEditing = false);
                                }
                              } else {
                                setState(() => _isEditing = true);
                              }
                            },
                      icon: Icon(
                        _isEditing
                            ? (hasChanged ? Icons.check : Icons.close)
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: UserAvatar.medium(
                            isEditable: _isEditing,
                            photoURL: _logoURL ?? organizer?.logoURL,
                            displayName: _organizerCopy?.companyName,
                            onNameChanged: (String name) {
                              setState(() {
                                _organizerCopy = _organizerCopy?.copyWith(
                                  companyName: name,
                                );
                              });
                            },
                            onPhotoChanged: (String photo) {
                              setState(() {
                                _logoURL = photo;
                              });
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        EditableListField<Industry, Set<Industry>>(
                          initialValue: _organizerCopy?.industry != null
                              ? {_organizerCopy!.industry!}
                              : {},
                          isEditable: _isEditing,
                          options: Industry.values.toSet(),
                          getOptionLabel: (industry) => industry.label,
                          title: 'Industry',
                          decoration: const InputDecoration(
                            labelText: 'Industry',
                            prefixIcon: Icon(Icons.factory),
                          ),
                          onChanged: (industries) => setState(
                            () => _organizerCopy = _organizerCopy?.copyWith(
                              industry: industries.firstOrNull,
                            ),
                          ),
                          validator: (industries) =>
                              industries.isEmpty ? 'Select an industry' : null,
                        ),

                        const SizedBox(height: 16),
                        
                        EditableLocationField(
                          initialValue: _organizerCopy?.address,
                          isEditable: _isEditing,
                          onChanged: (location) => setState(
                            () => _organizerCopy = _organizerCopy?.copyWith(
                              address: location,
                            ),
                          ),
                          validator: (location) =>
                              location == null ? 'Address required' : null,
                        ),

                        const SizedBox(height: 16),

                        EditablePhoneField(
                          initialValue: _organizerCopy?.phone ?? '',
                          isEditable: _isEditing,
                          isRequired: true,
                          onChanged: (phone) => setState(
                            () => _organizerCopy = _organizerCopy?.copyWith(
                              phone: phone,
                            ),
                          ),
                          validator: (phone) =>
                              (phone.isEmpty) ? 'Phone number required' : null,
                        ),

                        const SizedBox(height: 16),

                        EditableWebsiteField(
                          initialValue: _organizerCopy?.website,
                          isEditable: _isEditing,
                          onChanged: (website) => setState(
                            () => _organizerCopy = _organizerCopy?.copyWith(
                              website: website,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        
                        EditableTextField(
                          initialValue: _organizerCopy?.vatNumber,
                          isEditable: _isEditing,
                          decoration: const InputDecoration(
                            labelText: 'VAT Number',
                            prefixIcon: Icon(Icons.business),
                          ),
                          onChanged: (vat) => setState(
                            () => _organizerCopy = _organizerCopy?.copyWith(
                              vatNumber: vat,
                            ),
                          ),
                          validator: (vat) => (vat == null || vat.isEmpty)
                              ? 'VAT number required'
                              : null,
                        ),

                        const SizedBox(height: 16),

                        EditableIBANField(
                          initialValue: _organizerCopy?.iban,
                          isEditable: _isEditing,
                          isRequired: true,
                          onChanged: (iban) => setState(
                            () => _organizerCopy = _organizerCopy?.copyWith(
                              iban: iban,
                            ),
                          ),
                          validator: (iban) => (iban == null || iban.isEmpty)
                              ? 'IBAN required'
                              : null,
                        ),

                        if (!isOrganizer)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _saveOrCreate,
                              child: const Text('Create Organizer Profile'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}