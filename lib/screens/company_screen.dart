import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crowdpass/models/company.dart';
import 'package:crowdpass/providers/auth_provider.dart';
import 'package:crowdpass/providers/company_provider.dart';
import 'package:crowdpass/widgets/editable_list_field.dart';
import 'package:crowdpass/widgets/editable_address_field.dart';
import 'package:crowdpass/widgets/editable_phone_field.dart';
import 'package:crowdpass/widgets/editable_text_field.dart';
import 'package:crowdpass/widgets/editable_website_field.dart';
import 'package:crowdpass/widgets/error_dialog.dart';
import 'package:crowdpass/widgets/user_avatar.dart';

class CompanyScreen extends ConsumerStatefulWidget {
  const CompanyScreen({super.key});

  @override
  ConsumerState<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends ConsumerState<CompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;
  String? _logoURL;
  Company? _companyCopy;

  // Initialize the local copy only if it's currently null to prevent overwriting user typing
  void _initCopy(Company? original) {
    _companyCopy ??= original ?? const Company(name: '', phone: '');
  }

  Future<void> _saveOrCreate(String? existingId) async {
    if (!_formKey.currentState!.validate()) return;
    if (_companyCopy == null) return;

    try {
      if (existingId == null || existingId.isEmpty) {
        await ref
            .read(companyNotifier.notifier)
            .createCompany(_companyCopy!, logoURL: _logoURL);
      } else {
        await ref
            .read(companyNotifier.notifier)
            .updateCompany(_companyCopy!, logoURL: _logoURL);
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
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
        ),
        body: Center(child: Text('Auth Error: $err'))),
      data: (user) {
        if (user == null) return _buildAuthPlaceholder();

        final argsId = ModalRoute.of(context)?.settings.arguments as String?;
        final companyAsync = ref.watch(companyProvider(argsId ?? ''));

        return companyAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (err, _) => Scaffold(
            appBar: AppBar(
              title: const Text('Error'),
              leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
            ),
            body: Center(child: Text('Error: $err')),
          ),
          data: (company) {
            _initCopy(company);
            
            final isCreating = company == null;
            final isOwner = isCreating || company.ownerId == user.uid;
            
            // Auto-enable editing for new companies
            if (isCreating && !_isEditing) {
              _isEditing = true;
            }

            final hasChanged = _companyCopy != company || _logoURL != null;

            return Scaffold(
              appBar: AppBar(
                title: Text(isCreating ? 'Create Company' : '${company.name ?? 'Company Details'}'),
                actions: [
                  if (isOwner && !isCreating)
                    IconButton(
                      onPressed: isLoading ? null : () {
                        if (_isEditing && hasChanged) {
                          _saveOrCreate(company.id);
                        } else {
                          setState(() => _isEditing = !_isEditing);
                        }
                      },
                      icon: Icon(_isEditing 
                        ? (hasChanged ? Icons.check : Icons.close) 
                        : Icons.edit),
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
                            photoURL: _logoURL ?? _companyCopy?.logoURL,
                            labelText: 'Company Name',
                            displayName: _companyCopy?.name,
                            onNameChanged: (value) => setState(() => _companyCopy = _companyCopy?.copyWith(name: value)),
                            onPhotoChanged: (value) => setState(() => _logoURL = value),
                          ),
                        ),

                        const SizedBox(height: 16),
                        
                        // Industry Field
                        EditableListField<Industry, Set<Industry>>(
                          initialValue: _companyCopy?.industry != null
                              ? {_companyCopy!.industry!}
                              : {},
                          isEditable: _isEditing,
                          options: Industry.values.toSet(),
                          getOptionLabel: (i) => i.label,
                          title: 'Industry',
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.factory),
                          ),
                          onChanged: (value) => setState(
                            () => _companyCopy = _companyCopy?.copyWith(
                              industry: value.firstOrNull,
                            ),
                          ),
                          validator: (value) =>
                              value.isEmpty ? 'Industry required' : null,
                        ),
                        
                        const SizedBox(height: 16),

                        EditableAddressField(
                          location: _companyCopy?.address,
                          onLocationChanged: (value) => setState(
                            () => _companyCopy = _companyCopy?.copyWith(
                              address: value,
                            ),
                          ),
                          validator: (value) =>
                              value == null ? 'Address required' : null,
                        ),

                        const SizedBox(height: 16),

                        EditablePhoneField(
                          initialValue: _companyCopy?.phone ?? '',
                          isEditable: _isEditing,
                          isRequired: true,
                          onChanged: (value) => setState(() => _companyCopy = _companyCopy?.copyWith(phone: value)),
                        ),

                        const SizedBox(height: 16),

                        EditableTextField(
                          initialValue: _companyCopy?.vatNumber,
                          isEditable: _isEditing,
                          decoration: const InputDecoration(
                            labelText: 'VAT Number', 
                            prefixIcon: Icon(Icons.business),
                            hintText: 'e.g. DE123456789',
                          ),
                          onChanged: (value) => setState(() => _companyCopy = _companyCopy?.copyWith(vatNumber: value)),
                          validator: (value) => (value == null || value.isEmpty) ? 'VAT required' : null,
                        ),
                                                
                        const SizedBox(height: 16),

                        EditableWebsiteField(
                          initialValue: _companyCopy?.website,
                          isEditable: _isEditing,
                          onChanged: (value) => setState(() => _companyCopy = _companyCopy?.copyWith(website: value)),
                        ),

                        if (isCreating)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: ElevatedButton(
                              onPressed: isLoading ? null : () => _saveOrCreate(null),
                              child: isLoading 
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
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