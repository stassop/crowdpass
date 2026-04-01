import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

import 'package:crowdpass/models/money.dart';
import 'package:crowdpass/widgets/editable_text_field.dart';

class EditableMoneyField extends StatefulWidget {
  const EditableMoneyField({
    super.key,
    this.initialMoney,
    this.initialValue,
    this.initialCurrency,
    this.decoration,
    this.isEditable = true,
    this.isCurrencyEditable = true,
    this.onChanged,
    this.textStyle,
    this.validator,
    this.isRequired = false, // Default to false
  });

  final Money? initialMoney;
  final double? initialValue;
  final Currency? initialCurrency;
  final bool isEditable;
  final bool isCurrencyEditable;
  final InputDecoration? decoration;
  final TextStyle? textStyle;
  final void Function(Money)? onChanged;
  final String? Function(Money)? validator;
  final bool isRequired;

  @override
  State<EditableMoneyField> createState() => _EditableMoneyFieldState();
}

class _EditableMoneyFieldState extends State<EditableMoneyField> {
  late Currency _currency;
  late double _amount;
  late final Future<List<Currency>> _currenciesFuture;
  late final TextEditingController _controller;

  Money get _money => Money(amount: _amount, currency: _currency);

  @override
  void initState() {
    super.initState();
    
    _currency = widget.initialMoney?.currency ?? widget.initialCurrency ?? Currency.eur;
    _amount = widget.initialMoney?.amount ?? widget.initialValue ?? 0.0;

    _controller = TextEditingController(
      text: widget.isEditable ? _valueToString(_amount) : _money.toString(),
    );

    _currenciesFuture = _loadCurrencies();
  }

  Future<List<Currency>> _loadCurrencies() async {
    try {
      final jsonString = await rootBundle.loadString('assets/json/currencies.json');
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      final List<dynamic> currenciesRaw = jsonData['currencies'];
      
      final currencies = currenciesRaw.map((json) => Currency.fromJson(json)).toList();
      final defaultCurrency = _findDefaultInList(currencies);
      final target = widget.initialMoney?.currency ?? widget.initialCurrency;

      if (!mounted) return currencies;

      final resolvedCurrency = target != null 
          ? currencies.firstWhere(
              (c) => c.isoCode == target.isoCode,
              orElse: () => defaultCurrency,
            )
          : defaultCurrency;

      if (_currency != resolvedCurrency) {
        _currency = resolvedCurrency;
        
        // Update the controller so the UI reflects the correct currency symbol when read-only
        if (!widget.isEditable) {
          _controller.text = _money.toString(); 
        }
      }
      
      return currencies;
    } catch (error) {
      debugPrint('Currency loading error: $error');
      throw Exception('Failed to load currencies');
    }
  }

  Currency _findDefaultInList(List<Currency> currencies) {
    if (currencies.isEmpty) return Currency.eur;

    // First try to find a currency matching the user's locale
    final locale = Intl.getCurrentLocale();
    final countryCode = locale.contains('_') ? locale.split('_').last : '';
    
    for (var c in currencies) {
      if (c.countries.contains(countryCode)) {
        return c;
      }
    }

    // If no match, try to find a currency matching the local currency code
    final String? localCurrencyCode = NumberFormat().currencyName;
    for (var c in currencies) {
      if (c.isoCode == localCurrencyCode) {
        return c;
      }
    }

    // Fallback to the first currency in the list
    return currencies.first;
  }

  Widget _getCurrencyIcon(Currency currency) {
    switch (currency.symbol) {
      case '\$': return const Icon(Icons.attach_money);
      case '€': return const Icon(Icons.euro_symbol);
      case '£': return const Icon(Icons.currency_pound);
      case '¥': return const Icon(Icons.currency_yen);
      case '₹': return const Icon(Icons.currency_rupee);
      case '₽': return const Icon(Icons.currency_ruble);
      case '₺': return const Icon(Icons.currency_lira);
      case '₣': return const Icon(Icons.currency_franc);
      case 'Ұ': return const Icon(Icons.currency_yuan);
      default: return const Icon(Icons.monetization_on);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(EditableMoneyField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialMoney != oldWidget.initialMoney && widget.initialMoney != null) {
      _currency = widget.initialMoney!.currency;
      _amount = widget.initialMoney!.amount;
      
      final updatedText = widget.isEditable ? _valueToString(_amount) : _money.toString();
      
      if (_controller.text != updatedText) {
        _controller.text = updatedText;
        
        // FIX: Corrected cursor positioning using TextSelection.collapsed
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
      }
    }
  }

  void _onCurrencyChanged(Currency currency) {
    setState(() => _currency = currency);
    widget.onChanged?.call(_money);
  }

  void _onTextChanged(String text) {
    if (text.endsWith('.') || text.endsWith(',')) return;

    final parsed = double.tryParse(text.replaceAll(',', '.')) ?? 0.0;
    if (parsed != _amount) {
      _amount = parsed;
      widget.onChanged?.call(_money);
    }
  }

  String _valueToString(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Currency>>(
      future: _currenciesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 48, child: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasError) {
          return const Center(child: Text('Failed to load currencies'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No currencies available'));
        }

        final currencies = snapshot.data!;

        final currencyMenu = PopupMenuButton<Currency>(
          padding: EdgeInsets.zero,
          initialValue: _currency,
          onSelected: _onCurrencyChanged,
          enabled: widget.isCurrencyEditable,
          icon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 8),
              Text(
                _currency.symbol,
                style: widget.textStyle ?? Theme.of(context).textTheme.bodyLarge,
              ),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
          itemBuilder: (context) => currencies.map((currency) {
            return PopupMenuItem<Currency>(
              value: currency,
              child: Text('${currency.name} (${currency.symbol})'),
            );
          }).toList(),
        );

        return EditableTextField(
          controller: _controller,
          isEditable: widget.isEditable,
          textStyle: widget.textStyle,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          onChanged: _onTextChanged,
          validator: (_) {
            if (widget.isRequired && _amount == 0) {
              return 'Amount is required';
            }
            return widget.validator?.call(_money);
          },
          decoration: (widget.decoration ?? const InputDecoration()).copyWith(
            prefixIcon: widget.isEditable ? currencyMenu : _getCurrencyIcon(_currency),
          ),
        );
      },
    );
  }
}