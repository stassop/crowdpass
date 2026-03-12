import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';

// Assuming these paths are correct for your project
import 'package:crowdpass/models/country.dart';
import 'package:crowdpass/widgets/editable_text_field.dart';

class EditablePhoneField extends StatefulWidget {
  const EditablePhoneField({
    super.key,
    this.decoration,
    this.initialValue,
    this.onChanged,
    this.textStyle,
    this.title,
    this.isEditable = true,
    this.isRequired = false,
    this.validator,
  });

  final Function(String)? onChanged;
  final String? Function(String)? validator;
  final InputDecoration? decoration;
  final String? initialValue;
  final bool isEditable;
  final bool isRequired;
  final String? title;
  final TextStyle? textStyle;

  @override
  State<StatefulWidget> createState() => _EditablePhoneFieldState();
}

class _EditablePhoneFieldState extends State<EditablePhoneField> {
  late final Future<List<Country>> _countriesFuture;
  Country? _selectedCountry;
  String _localPhoneNumber = '';

  // Updated regex to validate the number part specifically (min 7 digits)
  static final RegExp _phoneNumberPattern = RegExp(r'^[0-9\s\-()]{7,}$');

  @override
  void initState() {
    super.initState();
    _countriesFuture = _getCountries();
  }

  Future<List<Country>> _getCountries() async {
    try {
      final jsonString = await rootBundle.loadString('assets/json/countries.json');
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      final List<Country> countries = (jsonData['countries'] as List)
          .map((e) => Country.fromJson(e as Map<String, dynamic>))
          .toList();

      _parseInitialValue(countries);
      return countries;
    } catch (error) {
      debugPrint('Country loading error: $error');
      throw Exception('Failed to load countries');
    }
  }

  void _parseInitialValue(List<Country> countries) {
    final input = widget.initialValue ?? '';
    
    // Sort countries by phoneCode length descending to match longest prefix first (e.g., +1242 before +1)
    final sortedCountries = List<Country>.from(countries)
      ..sort((a, b) => b.phoneCode.length.compareTo(a.phoneCode.length));

    for (var country in sortedCountries) {
      if (input.startsWith(country.phoneCode)) {
        _selectedCountry = country;
        _localPhoneNumber = input.substring(country.phoneCode.length).trim();
        return;
      }
    }

    // Fallback if no match is found (defaulting to first country or empty)
    _selectedCountry = countries.isNotEmpty ? countries.first : null;
    _localPhoneNumber = input;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Country>>(
      future: _countriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError || !snapshot.hasData) {
          return const Center(child: Text('Failed to load countries'));
        }

        final countries = snapshot.data!;
        // Ensure we have a default if parsing failed
        _selectedCountry ??= countries.first;

        final countryMenu = PopupMenuButton<Country>(
          padding: EdgeInsets.zero,
          icon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _selectedCountry?.phoneCode ?? '',
                style: widget.textStyle ?? Theme.of(context).textTheme.bodyLarge,
              ),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
          initialValue: _selectedCountry,
          itemBuilder: (context) => countries.map((country) {
            return PopupMenuItem<Country>(
              value: country,
              child: Text('${country.name} (${country.phoneCode})'),
            );
          }).toList(),
          onSelected: (country) {
            setState(() {
              _selectedCountry = country;
            });
          },
          enabled: widget.isEditable,
        );

        return EditableTextField(
          // Logic: Show full number if read-only, else just the local part
          initialValue: widget.isEditable 
              ? _localPhoneNumber 
              : '${_selectedCountry?.phoneCode ?? ''} $_localPhoneNumber',
          isEditable: widget.isEditable,
          keyboardType: TextInputType.phone,
          decoration: (widget.decoration ?? const InputDecoration()).copyWith(
            border: const OutlineInputBorder(),
            prefixIcon: widget.isEditable ? countryMenu : const Icon(Icons.phone),
            labelText: widget.decoration?.labelText ?? 'Phone Number',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return widget.isRequired ? 'Phone number is required' : null;
            }

            // Validates the number after the country code
            if (!_phoneNumberPattern.hasMatch(value)) {
              return 'Enter a valid phone number';
            }

            if (widget.validator != null) {
              return widget.validator!(value);
            }

            return null;
          },
          onChanged: (value) {
            _localPhoneNumber = value;
            if (widget.onChanged != null) {
              // Always return the full E.164-ish string to the parent
              widget.onChanged!('${_selectedCountry?.phoneCode ?? ''}$value');
            }
          },
        );
      },
    );
  }
}