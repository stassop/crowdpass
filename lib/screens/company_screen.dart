import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:crowdpass/models/company.dart';
import 'package:crowdpass/models/location.dart';
import 'package:crowdpass/providers/auth_provider.dart';
import 'package:crowdpass/providers/company_provider.dart';

import 'package:crowdpass/widgets/editable_text_field.dart';
import 'package:crowdpass/widgets/editable_website_field.dart';
import 'package:crowdpass/widgets/error_dialog.dart';
import 'package:crowdpass/widgets/user_avatar.dart';
import 'package:crowdpass/widgets/editable_address_field.dart';
import 'package:crowdpass/widgets/editable_list_field.dart';
import 'package:crowdpass/widgets/editable_phone_field.dart';

class CompanyScreen extends ConsumerStatefulWidget {
  const CompanyScreen({super.key});

  @override
  ConsumerState<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends ConsumerState<CompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  Industry? _industry;
  Location? _address;
  String? _email;
  String? _iban;
  String? _logoURL;
  String? _name;
  String? _ownerId;
  String? _phone;
  String? _vatNumber;
  String? _website;

  bool _hasChanged = false;
  bool _isEditing = false;

  void _updateHasChanged(Company? company) {
    _hasChanged =
        _name != company?.name ||
        _industry != company?.industry ||
        _address != company?.address ||
        _phone != company?.phone ||
        _vatNumber != company?.vatNumber ||
        _website != company?.website ||
        _email != company?.email ||
        _ownerId != company?.ownerId ||
        _iban != company?.iban ||
        _logoURL != company?.logoURL;
  }

  // Set fields from company
  void _resetFields(Company? company) {
    if (company == null) return;
    _name = company.name;
    _industry = company.industry;
    _address = company.address;
    _phone = company.phone;
    _vatNumber = company.vatNumber;
    _website = company.website;
    _email = company.email;
    _ownerId = company.ownerId;
    _iban = company.iban;
    _logoURL = company.logoURL;
    _updateHasChanged(company);
  }

  Future<void> _saveOrCreate(String? companyId) async {
    if (!_formKey.currentState!.validate()) return;

    try {
      if (companyId == null || companyId.isEmpty) {
        await ref.read(companyNotifier.notifier).createCompany(
          address: _address!,
          email: _email!,
          iban: _iban!,
          industry: _industry!,
          logoPath: _logoURL,
          name: _name!,
          phone: _phone!,
          vatNumber: _vatNumber!,
          website: _website,
        );
      } else {
        await ref.read(companyNotifier.notifier).updateCompany(
          address: _address,
          companyId: companyId,
          email: _email,
          iban: _iban,
          industry: _industry,
          logoPath: _logoURL,
          name: _name,
          ownerId: _ownerId,
          phone: _phone,
          vatNumber: _vatNumber,
          website: _website,
        );
      }

      if (mounted) {
        setState(() {
          _isEditing = false;
          _logoURL = null; // Reset local image path after success
        });
      }
    } catch (e) {
      if (mounted) {
        ErrorDialog.show(context, title: 'Save Failed', message: '$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authProvider);
    final isLoading = ref.watch(companyNotifier).isLoading;

    return authAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          leading: BackButton(
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: Center(child: Text('Auth Error: $err')),
      ),
      data: (user) {
        if (user == null) return _buildAuthPlaceholder();

        final argsId = ModalRoute.of(context)?.settings.arguments as String?;
        // Now passing argsId (which can be null) directly.
        // If null, the provider fetches the current user's company.
        final companyAsync = ref.watch(companyProvider(argsId));

        return companyAsync.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, _) => Scaffold(
            appBar: AppBar(
              title: const Text('Error'),
              leading: BackButton(
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            body: Center(child: Text('Error: $err')),
          ),
          data: (company) {
            // Set fields from company when new value arrives
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _resetFields(company));
            });

            final isCreating = company == null;
            final isOwner = isCreating || (company.ownerId == user.uid);

            // Auto-enable editing for new companies
            if (isCreating && !_isEditing) {
              _isEditing = true;
            }

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  isCreating
                      ? 'Create Company'
                      : company.name,
                ),
                actions: [
                  if (isOwner && !isCreating)
                    IconButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              if (_isEditing && _hasChanged) {
                                _saveOrCreate(company.id);
                              } else {
                                setState(() => _isEditing = !_isEditing);
                              }
                            },
                      icon: Icon(
                        _isEditing
                            ? (_hasChanged ? Icons.check : Icons.close)
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
                            isEditable: _isEditing,
                            photoURL: _logoURL,
                            labelText: 'Company Name',
                            displayName: _name,
                            onNameChanged: (value) => setState(() {
                              _name = value;
                              _updateHasChanged(company);
                            }),
                            onPhotoChanged: (value) => setState(() {
                              _logoURL = value;
                              _updateHasChanged(company);
                            }),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Industry Field
                        EditableListField<Industry, Set<Industry>>(
                          initialValue: _industry != null ? {_industry!} : {},
                          isEditable: _isEditing,
                          options: Industry.values.toSet(),
                          getOptionLabel: (i) => i.label,
                          title: 'Industry',
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.factory),
                          ),
                          onChanged: (value) => setState(() {
                            _industry = value.firstOrNull;
                            _updateHasChanged(company);
                          }),
                          validator: (value) => value.isEmpty ? 'Industry required' : null,
                        ),

                        const SizedBox(height: 16),

                        EditableAddressField(
                          location: _address,
                          isEditable: _isEditing,
                          onLocationChanged: (value) => setState(() {
                            _address = value;
                            _updateHasChanged(company);
                          }),
                          validator: (value) => value == null ? 'Address required' : null,
                        ),

                        const SizedBox(height: 16),

                        EditablePhoneField(
                          initialValue: _phone,
                          isEditable: _isEditing,
                          isRequired: true,
                          onChanged: (value) => setState(() {
                            _phone = value;
                            _updateHasChanged(company);
                          }),
                        ),

                        const SizedBox(height: 16),

                        EditableTextField(
                          initialValue: _vatNumber,
                          isEditable: _isEditing,
                          decoration: const InputDecoration(
                            labelText: 'VAT Number',
                            prefixIcon: Icon(Icons.business),
                            hintText: 'e.g. DE123456789',
                          ),
                          onChanged: (value) => setState(() {
                            _vatNumber = value;
                            _updateHasChanged(company);
                          }),
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'VAT required'
                              : null,
                        ),

                        const SizedBox(height: 16),

                        EditableWebsiteField(
                          initialValue: _website,
                          isEditable: _isEditing,
                          onChanged: (value) => setState(() {
                            _website = value;
                            _updateHasChanged(company);
                          }),
                        ),

                        if (isCreating)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () => _saveOrCreate(null),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Create Company'),
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

  Widget _buildAuthPlaceholder() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/sign_in/'),
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}
