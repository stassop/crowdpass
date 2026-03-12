import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';

import 'package:crowdpass/models/country.dart';
import 'package:crowdpass/widgets/editable_list_field.dart';

class EditableCountryField extends StatefulWidget {
  const EditableCountryField({
    super.key,
    this.decoration,
    this.initialValue,
    this.isEditable = false,
    this.isMultiple = true,
    this.onChanged,
    this.textStyle,
    this.title,
    this.validator,
  });

  final bool isEditable;
  final bool isMultiple;
  final Function(Set<Country>)? onChanged;
  final String? Function(Set<Country>)? validator;
  final InputDecoration? decoration;
  final Set<Country>? initialValue;
  final String? title;
  final TextStyle? textStyle;

  @override
  State<StatefulWidget> createState() => _EditableCountryFieldState();
}

class _EditableCountryFieldState extends State<EditableCountryField> {
  late final Future<Set<Country>> _countriesFuture;

  @override
  void initState() {
    super.initState();
    _countriesFuture = _getCountries();
  }

  Future<Set<Country>> _getCountries() async {
    try {
      final jsonString = await rootBundle.loadString('assets/json/countries.json');
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      return (jsonData['countries'] as List)
          .map((e) => Country.fromJson(e as Map<String, dynamic>))
          .toSet();
    } catch (error) {
      debugPrint('Country loading error: $error');
      throw Exception('Failed to load countries');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Set<Country>>(
      future: _countriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return const Center(child: Text('Failed to load countries'));
        } else if (snapshot.hasData) {
          return EditableListField<Country, void>(
            getOptionLabel: (Country country) => '${country.name} (${country.nativeName})',
            decoration: (widget.decoration ?? const InputDecoration()).copyWith(
              prefixIcon: const Icon(Icons.public),
              labelText: widget.decoration?.labelText ?? 'Countries',
            ),
            initialValue: widget.initialValue,
            isEditable: widget.isEditable,
            isMultiple: widget.isMultiple,
            options: snapshot.data!,
            textStyle: widget.textStyle,
            title: widget.title ?? 'Countries',
            onChanged: widget.onChanged,
            validator: widget.validator,
          );
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }
}
