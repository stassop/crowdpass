import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

import 'package:crowdpass/models/money.dart';
import 'package:crowdpass/widgets/editable_number_field.dart';

class EditableMoneyField extends StatefulWidget {
  const EditableMoneyField({
    super.key,
    this.initialMoney,
    this.initialAmount,
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
  final double? initialAmount;
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

  Money get _money => Money(amount: _amount, currency: _currency);

  @override
  void initState() {
    super.initState();

    _currency = widget.initialMoney?.currency ??
        widget.initialCurrency ??
        Currency.eur;
    _amount = widget.initialMoney?.amount ?? widget.initialAmount ?? 0.0;

    _currenciesFuture = _loadCurrencies();
  }

  Future<List<Currency>> _loadCurrencies() async {
    try {
      final jsonString = await rootBundle.loadString('assets/json/currencies.json');
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      final List<dynamic> currenciesRaw = jsonData['currencies'];

      final currencies = currenciesRaw.map((json) => Currency.fromJson(json)).toList();
      final defaultCurrency = _findDefaultInList(currencies);
      final initialCurrency = widget.initialMoney?.currency ?? widget.initialCurrency;

      if (!mounted) return currencies;

      // Try to find the initial currency in the loaded list, fallback to default if not found
      final resolvedCurrency = initialCurrency != null
          ? currencies.firstWhere(
              (currency) => currency.isoCode == initialCurrency.isoCode,
              orElse: () => defaultCurrency,
            )
          : defaultCurrency;

      if (_currency != resolvedCurrency) {
        _currency = resolvedCurrency;
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

    for (var currency in currencies) {
      if (currency.countries.contains(countryCode)) {
        return currency;
      }
    }

    // If no match, try to find a currency matching the local currency code
    final String? localCurrencyCode = NumberFormat().currencyName;
    for (var currency in currencies) {
      if (currency.isoCode == localCurrencyCode) {
        return currency;
      }
    }

    // Fallback to the first currency in the list
    return currencies.first;
  }

  Widget _getCurrencyIcon(Currency currency) {
    switch (currency.symbol) {
      case '\$':
        return const Icon(Icons.attach_money);
      case '€':
        return const Icon(Icons.euro_symbol);
      case '£':
        return const Icon(Icons.currency_pound);
      case '¥':
        return const Icon(Icons.currency_yen);
      case '₹':
        return const Icon(Icons.currency_rupee);
      case '₽':
        return const Icon(Icons.currency_ruble);
      case '₺':
        return const Icon(Icons.currency_lira);
      case '₣':
        return const Icon(Icons.currency_franc);
      case 'Ұ':
        return const Icon(Icons.currency_yuan);
      default:
        return const Icon(Icons.monetization_on);
    }
  }

  void _onCurrencyChanged(Currency currency) {
    setState(() => _currency = currency);

    // Defer notification to avoid triggering rebuild/validation during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onChanged?.call(_money);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Currency>>(
      future: _currenciesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              height: 48, child: Center(child: CircularProgressIndicator()));
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

        return EditableNumberField(
          isEditable: widget.isEditable,
          hasDecimals: true,
          initialValue: _amount,
          onChanged: (value) {
            setState(() => _amount = value?.toDouble() ?? 0.0);
            widget.onChanged?.call(_money);
          },
          validator: (_) {
            if (widget.isRequired && _amount == 0) {
              return 'Amount is required';
            }
            return widget.validator?.call(_money);
          },
          decoration: (widget.decoration ?? const InputDecoration()).copyWith(
            prefixIcon:
                widget.isEditable ? currencyMenu : _getCurrencyIcon(_currency),
          ),
        );
      },
    );
  }
}